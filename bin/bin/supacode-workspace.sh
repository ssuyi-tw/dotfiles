#!/bin/bash
# supacode-workspace — generate a multi-root Cursor/VS Code workspace
# containing every git worktree of a repo, so all parallel Supacode
# sessions show up in ONE window with ONE Source Control panel (diffs
# grouped per worktree) instead of N separate editor windows.
#
# Usage:
#   supacode-workspace.sh [-n|--no-open] [-e cursor|code] [repo-path]
#
#   repo-path   Any path inside the target repo (default: cwd).
#   -n          Generate only; do not open the editor.
#   -e EDITOR   Editor CLI to open with (default: cursor).
#
# Writes: ~/.supacode/workspaces/<repo-name>.code-workspace
# Re-run any time worktrees are added/removed to refresh the list.

set -euo pipefail

editor="cursor"
open=1
repo_arg=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--no-open) open=0; shift ;;
    -e|--editor)  editor="$2"; shift 2 ;;
    -h|--help)    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)            repo_arg="$1"; shift ;;
  esac
done

command -v jq >/dev/null || { echo "supacode-workspace: jq is required" >&2; exit 1; }

cd "${repo_arg:-$PWD}"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "supacode-workspace: not inside a git repo" >&2; exit 1; }

# Resolve the main worktree (dir holding the shared .git). --git-common-dir can
# be relative when run from the main checkout, so force it absolute.
git_dir="$(cd "$(git rev-parse --git-common-dir)" && pwd)"
main_worktree="$(dirname "$git_dir")"
repo_name="$(basename "$main_worktree")"

# Output dir is overridable: export SUPACODE_WORKSPACE_DIR=~/somewhere
out="${SUPACODE_WORKSPACE_DIR:-$HOME/.cursor/workspaces}/${repo_name}.code-workspace"
mkdir -p "$(dirname "$out")"

# Parse `git worktree list --porcelain` into "path<TAB>branch" rows.
# Git lists the main worktree first, so it stays at the top of the list.
folders="$(
  git worktree list --porcelain | awk '
    /^worktree /  { path = substr($0, 10) }
    /^branch /    { br = $0; sub(/^branch refs\/heads\//, "", br) }
    /^detached$/  { br = "" }
    /^$/          { if (path != "") { print path "\t" br; path = ""; br = "" } }
    END           { if (path != "") print path "\t" br }
  ' | while IFS=$'\t' read -r path br; do
        [ -n "$path" ] || continue
        jq -n --arg name "${br:-$(basename "$path")}" --arg path "$path" \
          '{name: $name, path: $path}'
      done | jq -s '.'
)"

# Refresh the folder list only. On an existing file, preserve every other
# top-level key (settings, extensions, launch, tasks) so workspace-specific
# tweaks survive regeneration. Seed default git settings only on first create.
tmp="$(mktemp)"
if [ -f "$out" ] && jq -e . "$out" >/dev/null 2>&1; then
  jq --argjson folders "$folders" '.folders = $folders' "$out" > "$tmp"
else
  jq -n --argjson folders "$folders" '{
    folders: $folders,
    settings: {
      "git.openRepositoryInParentFolders": "always",
      "git.autoRepositoryDetection": true
    }
  }' > "$tmp"
fi
mv "$tmp" "$out"

count="$(jq 'length' <<<"$folders")"
echo "supacode-workspace: $count worktree(s) -> $out"

if [ "$open" -eq 1 ]; then
  command -v "$editor" >/dev/null \
    && "$editor" "$out" \
    || echo "supacode-workspace: editor '$editor' not found; open $out manually" >&2
fi
