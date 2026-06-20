#!/bin/bash

source "$CONFIG_DIR/colors.sh"

# Sketchybar execs plugins with SIGCHLD=SIG_IGN, which Ruby inherits — waitpid
# then returns ECHILD, so brew's `Process::Status#exitstatus` is nil and brew
# crashes (`undefined method 'exitstatus' for nil`). In brew 5.1.6 this hit
# Hardware::CPU.cores; in 6.x it hits the cask version check (bundle_version).
# A bash `trap - CHLD` can't fix it (POSIX: a signal ignored on shell entry
# stays ignored). Instead, exec brew through perl after resetting SIGCHLD to
# its default disposition so brew can reap its own children.
export HOMEBREW_DOWNLOAD_CONCURRENCY=4
brew() { perl -e '$SIG{CHLD}="DEFAULT"; exec @ARGV' brew "$@"; }

if ! OUTDATED="$(brew outdated 2>/dev/null)"; then
  sketchybar --set "$NAME" label=! icon.color=$RED
  exit 0
fi
COUNT="$(printf '%s\n' "$OUTDATED" | grep -c '^[^[:space:]]')"

COLOR=$RED

case "$COUNT" in
  0)          COLOR=$GREEN;  COUNT=􀆅 ;;
  [1-9])      COLOR=$WHITE   ;;
  [1-2][0-9]) COLOR=$YELLOW  ;;
  [3-5][0-9]) COLOR=$ORANGE  ;;
  *)          COLOR=$RED     ;;
esac

sketchybar --set $NAME label=$COUNT icon.color=$COLOR
