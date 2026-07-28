#!/usr/bin/env bash
#
# review-pr.sh — spin up a Herdr worktree + interactive Claude (automode)
#                to review a peer PR in the BACKGROUND (does not steal focus).
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
#   2. Creates a managed Herdr worktree off the PR head (shows in the UI).
#   3. Starts ONE Claude agent and submits `/review <N>`.
#   4. Leaves focus unchanged while the review runs in the background.
#
# Notes:
#   - Herdr's worktree commands are synchronous and return workspace/tab/pane IDs.
#   - `herdr worktree remove` keeps the git branch. A clean rebuild drops that
#     script-owned branch before creating the replacement worktree.
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
# Local checkout to fetch into; defaults to the current repo's root.
MAIN="${MAIN:-$(git rev-parse --show-toplevel 2>/dev/null || true)}"
[ -n "$MAIN" ] && [ -d "$MAIN" ] || { echo "review-pr.sh: no local checkout — run inside the repo or set MAIN=/path/to/clone" >&2; exit 1; }
command -v herdr >/dev/null || { echo "review-pr.sh: herdr is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "review-pr.sh: jq is required" >&2; exit 1; }
[ "${HERDR_ENV:-}" = "1" ] || { echo "review-pr.sh: run this command inside Herdr" >&2; exit 1; }
BR="pr-${PR}-review"
NAME="pr-${PR}"

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

# Resolve an existing checkout by the script-owned review branch. The workspace
# ID is empty when the checkout exists on disk but is not currently open in Herdr.
WORKTREES_JSON="$(herdr worktree list --cwd "$MAIN" --json)"
WT_PATH="$(jq -r --arg branch "$BR" \
  '[.result.worktrees[] | select(.branch == $branch and .is_linked_worktree)] | first | .path // empty' \
  <<<"$WORKTREES_JSON")"
WT_WORKSPACE_ID="$(jq -r --arg branch "$BR" \
  '[.result.worktrees[] | select(.branch == $branch and .is_linked_worktree)] | first | .open_workspace_id // empty' \
  <<<"$WORKTREES_JSON")"

# Optional teardown for a clean rebuild. A closed checkout must be opened first
# because Herdr removes worktrees by workspace ID.
if [ "${RECREATE:-0}" = "1" ] && [ -n "$WT_PATH" ]; then
  echo "RECREATE=1 → removing existing worktree"
  if [ -z "$WT_WORKSPACE_ID" ]; then
    OPEN_JSON="$(herdr worktree open --cwd "$MAIN" --path "$WT_PATH" --label "$NAME" --no-focus --json)"
    WT_WORKSPACE_ID="$(jq -er '.result.workspace.workspace_id' <<<"$OPEN_JSON")"
  fi
  herdr worktree remove --workspace "$WT_WORKSPACE_ID" --force --json >/dev/null
  git worktree prune
  WT_PATH=""
  WT_WORKSPACE_ID=""
fi

# Reuse an open workspace by adding one review tab. Opening a closed worktree or
# creating a new one already provides an empty root pane for the review.
if [ -n "$WT_PATH" ] && [ -n "$WT_WORKSPACE_ID" ]; then
  echo "worktree already exists — reusing it (RECREATE=1 to rebuild)"
  TAB_JSON="$(herdr tab create --workspace "$WT_WORKSPACE_ID" --cwd "$WT_PATH" --label "review #$PR" --no-focus)"
  PANE_ID="$(jq -er '.result.root_pane.pane_id' <<<"$TAB_JSON")"
elif [ -n "$WT_PATH" ]; then
  echo "worktree already exists — opening it (RECREATE=1 to rebuild)"
  OPEN_JSON="$(herdr worktree open --cwd "$MAIN" --path "$WT_PATH" --label "$NAME" --no-focus --json)"
  WT_WORKSPACE_ID="$(jq -er '.result.workspace.workspace_id' <<<"$OPEN_JSON")"
  PANE_ID="$(jq -er '.result.root_pane.pane_id' <<<"$OPEN_JSON")"
else
  # Drop a stale script-owned branch left behind by a prior worktree removal.
  git branch -D "$BR" >/dev/null 2>&1 && echo "dropped stale branch $BR" || true

  CREATE_JSON="$(herdr worktree create --cwd "$MAIN" --branch "$BR" --base "origin/$HEAD_REF" --label "$NAME" --no-focus --json)"
  WT_PATH="$(jq -er '.result.worktree.path' <<<"$CREATE_JSON")"
  WT_WORKSPACE_ID="$(jq -er '.result.workspace.workspace_id' <<<"$CREATE_JSON")"
  PANE_ID="$(jq -er '.result.root_pane.pane_id' <<<"$CREATE_JSON")"
fi

# Start Claude in the returned background pane, then submit the review prompt.
# The per-process name stays unique when the same PR is reviewed more than once.
AGENT_NAME="review-pr-${PR}-$$"
for attempt in {1..30}; do
  if START_OUTPUT="$(herdr agent start "$AGENT_NAME" --kind claude --pane "$PANE_ID" -- --permission-mode auto 2>&1)"; then
    break
  fi

  ERROR_CODE="$(jq -r '.error.code // empty' <<<"$START_OUTPUT" 2>/dev/null || true)"
  if [ "$ERROR_CODE" != "agent_pane_busy" ]; then
    printf '%s\n' "$START_OUTPUT" >&2
    exit 1
  fi
  if [ "$attempt" -eq 30 ]; then
    echo "review-pr.sh: Herdr pane $PANE_ID was still busy after 15 seconds" >&2
    printf '%s\n' "$START_OUTPUT" >&2
    exit 1
  fi
  sleep 0.5
done
herdr agent prompt "$AGENT_NAME" "/review $PR" >/dev/null

echo "done — reviewing #$PR in the background at $WT_PATH (workspace $WT_WORKSPACE_ID)."
