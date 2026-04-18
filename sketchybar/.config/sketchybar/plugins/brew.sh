#!/bin/bash

source "$CONFIG_DIR/colors.sh"

# Sketchybar inherits SIGCHLD=SIG_IGN, so children of this script can't reap
# their own children — `$?` is unrecoverable in Ruby (POSIX: waitpid returns
# ECHILD when SIGCHLD is ignored). Brew 5.1.6's Hardware::CPU.cores crashes
# on the resulting nil $CHILD_STATUS. Setting HOMEBREW_DOWNLOAD_CONCURRENCY
# to a literal value bypasses the call into Hardware::CPU.cores entirely.
export HOMEBREW_DOWNLOAD_CONCURRENCY=4

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
