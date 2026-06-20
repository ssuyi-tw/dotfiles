#!/usr/bin/env bash
#
# review-pr.sh — spin up a Supacode worktree + interactive Claude (automode)
#                to review a peer PR, in the BACKGROUND (does not steal focus).
#
# Usage:  review-pr.sh list [owner/repo]        # list peer PRs pending your review
#         review-pr.sh <PR_NUMBER>             # spin up worktree + review it
#         RECREATE=1 review-pr.sh <PR_NUMBER>  # tear down & rebuild if it exists
#
# Repo + checkout are taken from the current git repo. Override with env:
#   REPO=owner/repo   target a different GitHub repo
#   MAIN=/path/clone  local checkout to fetch into (default: this repo's root)
#   BASE=branch       diff base for /review (default: the PR's base branch)
#
# What it does:
#   1. Resolves the PR's head + base branches and fetches them.
#   2. Creates a managed Supacode worktree off the PR head (shows in the UI).
#   3. Opens ONE Claude tab running `claude --permission-mode auto /review <N>`.
#   4. Restores focus to where you were — the review runs in the background.
#
# Notes:
#   - supacode `worktree-new` and `tab new` are async/fire-and-forget; we poll
#     the worktree list until the app registers it, then create the tab ONCE.
#   - `supacode worktree delete` removes the folder but KEEPS the git branch, so
#     a re-create with the same --branch collides. We drop the stale branch first.
#   - Depends on the repo's .husky/post-checkout being guarded against the null
#     SHA ($1 == 0000…) on new worktrees, or the app rolls the worktree back.
#
set -euo pipefail

CMD="${1:?usage: review-pr.sh list [owner/repo] | <PR_NUMBER>  (RECREATE=1, REPO/MAIN/BASE to override)}"

# Target repo: explicit REPO env (owner/repo) > the current dir's git remote.
# Auto-detect owner/repo from origin (git@host:owner/repo.git | https://host/owner/repo[.git]).
cwd_repo="$(git remote get-url origin 2>/dev/null | sed -E 's#\.git$##; s#^.*[:/]([^/]+/[^/]+)$#\1#' || true)"
case "$cwd_repo" in */*) ;; *) cwd_repo="" ;; esac
REPO="${REPO:-$cwd_repo}"

# List open peer PRs (not yours, not drafts, not bots) still pending review.
# "Pending" = reviewDecision != APPROVED. ACTION translates merge state into what
# to do: ready (review it) / PING-REBASE (conflicting — nudge author) / check
# (GitHub still computing mergeability; re-run). Sorted ready-first.
list_prs() {
  local repo="${1:-$REPO}" me
  me=$(gh api user --jq .login)
  echo "Peer PRs pending your review in $repo:"
  gh pr list --repo "$repo" --state open --limit 100 \
    --json number,title,author,baseRefName,reviewDecision,mergeable,isDraft,additions,deletions \
    --jq "
      [ .[]
        | select(.isDraft | not)
        | select(.author.is_bot | not)
        | select(.author.login != \"$me\")
        | select(.reviewDecision != \"APPROVED\")
        | . + (if   .mergeable==\"MERGEABLE\"   then {rank:0, action:\"ready\"}
               elif .mergeable==\"CONFLICTING\" then {rank:1, action:\"PING-REBASE\"}
               else                                  {rank:2, action:\"check\"} end) ]
      | sort_by(.rank, .number)
      | (\"PR\tACTION\tMERGE\tREVIEW\tSIZE\tAUTHOR\tBASE\tTITLE\"),
        (.[] | \"#\(.number)\t\(.action)\t\(.mergeable)\t\(.reviewDecision // \"NONE\")\t+\(.additions)/-\(.deletions)\t\(.author.login)\t→\(.baseRefName)\t\(.title)\")
    " | column -t -s $'\t'
}

# Dispatch: `list`/`ls` subcommand vs a PR number.
case "$CMD" in
  list|ls)
    repo="${2:-$REPO}"
    [ -n "$repo" ] || { echo "review-pr.sh: no repo — run inside a git repo or pass: list owner/repo" >&2; exit 1; }
    list_prs "$repo"; exit 0 ;;
esac

PR="$CMD"
# A non-numeric arg here is almost always a typo'd subcommand. Fail fast, before
# we hit the network or create a worktree.
[[ "$PR" =~ ^[0-9]+$ ]] || { echo "review-pr.sh: expected a PR number or 'list', got: '$PR'" >&2; exit 1; }
[ -n "$REPO" ] || { echo "review-pr.sh: no repo detected — run inside a git repo or set REPO=owner/repo" >&2; exit 1; }
SLUG="${REPO##*/}"
# Local checkout to fetch into; defaults to the current repo's root.
MAIN="${MAIN:-$(git rev-parse --show-toplevel 2>/dev/null || true)}"
[ -n "$MAIN" ] && [ -d "$MAIN" ] || { echo "review-pr.sh: no local checkout — run inside the repo or set MAIN=/path/to/clone" >&2; exit 1; }
BR="pr-${PR}-review"
NAME="pr-${PR}"
WT_PATH="$HOME/.supacode/repos/$SLUG/${NAME}"
# Supacode worktree id = the path with every "/" percent-encoded + trailing slash.
WT_ID="$(printf '%s/' "$WT_PATH" | sed 's:/:%2F:g')"

# Remember where we are so we can restore focus (keep the review in the background).
ORIG_WT="${SUPACODE_WORKTREE_ID:-}"
ORIG_TAB="${SUPACODE_TAB_ID:-}"

strip() { sed 's/\x1b\[[0-9;]*m//g'; }
# Supacode prints percent-encoded paths (…%2Fpr-352%2F), not literal slashes.
in_supacode_list() { supacode worktree list 2>/dev/null | strip | grep -qF "%2F${NAME}%2F"; }

cd "$MAIN"

read -r HEAD_REF BASE_REF MERGE_STATE < <(gh pr view "$PR" --repo "$REPO" --json headRefName,baseRefName,mergeable -q '"\(.headRefName) \(.baseRefName) \(.mergeable)"')
BASE="${BASE:-$BASE_REF}"   # diff base for /review; defaults to the PR's base branch
echo "PR #$PR  head=$HEAD_REF  base=$BASE  merge=$MERGE_STATE  →  worktree '$NAME' (branch $BR)"
if [ "$MERGE_STATE" = "CONFLICTING" ]; then
  echo "⚠  PR #$PR is CONFLICTING — the diff will include merge noise. Consider pinging the author to rebase first. Proceeding anyway…" >&2
fi

# Review base first, best-effort: a stale local "$BASE" beats aborting the run.
git fetch origin "$BASE" >/dev/null 2>&1 || echo "warn: couldn't fetch $BASE; /review will diff against a stale local base" >&2
# PR head is required — the worktree is built from origin/$HEAD_REF.
git fetch origin "$HEAD_REF" >/dev/null 2>&1 || { echo "ERROR: couldn't fetch PR head '$HEAD_REF' from origin" >&2; exit 1; }

# Optional teardown for a clean rebuild.
if [ "${RECREATE:-0}" = "1" ] && [ -d "$WT_PATH" ]; then
  echo "RECREATE=1 → removing existing worktree"
  supacode worktree delete -w "$WT_ID" >/dev/null 2>&1 || true
  for _ in $(seq 1 10); do [ -d "$WT_PATH" ] || break; sleep 1; done
  git worktree prune
fi

if [ -d "$WT_PATH" ]; then
  echo "worktree already exists — reusing it (RECREATE=1 to rebuild)"
else
  # Conflict-proof: drop a stale review branch left behind by a prior delete.
  git branch -D "$BR" >/dev/null 2>&1 && echo "dropped stale branch $BR" || true

  supacode repo worktree-new --branch "$BR" --base "origin/$HEAD_REF" --name "$NAME"

  echo -n "waiting for Supacode to register the worktree"
  for _ in $(seq 1 25); do
    in_supacode_list && { echo " ✓"; break; }
    echo -n "."; sleep 1
  done
  in_supacode_list || { echo; echo "ERROR: worktree never registered (husky hook? branch conflict?)" >&2; exit 1; }
fi

# Launch exactly ONE Claude review tab in automode. Two quirks, both handled:
#   - The terminal surface only instantiates reliably when the worktree is
#     focused, so we focus it first (brief flicker), then restore below.
#   - `supacode tab new -i` ALWAYS times out at the CLI yet still creates the tab
#     and runs the command async — so we tolerate the non-zero exit and do NOT
#     capture the UUID (it would be the error string). No retry loop = no forks.
supacode worktree focus -w "$WT_ID" >/dev/null 2>&1 || true
supacode tab new -w "$WT_ID" -i "claude --permission-mode auto '/review $PR'" >/dev/null 2>&1 || true
echo "launched Claude review (automode) in worktree '$NAME'"

# Let the async tab settle, then restore focus so the review runs in the background.
sleep 3
if [ -n "$ORIG_WT" ]; then
  supacode worktree focus -w "$ORIG_WT" >/dev/null 2>&1 || true
  [ -n "$ORIG_TAB" ] && supacode tab focus -w "$ORIG_WT" -t "$ORIG_TAB" >/dev/null 2>&1 || true
fi

echo "done — reviewing #$PR in the background. Switch to worktree '$NAME' to watch."
