#!/bin/bash

# set -x

export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

SKETCHYBAR="${SKETCHYBAR:-$(command -v sketchybar || echo /opt/homebrew/bin/sketchybar)}"
GH="${GH:-$(command -v gh || echo /opt/homebrew/bin/gh)}"

set_unavailable() {
  "$SKETCHYBAR" --set "$NAME" icon="$BELL" icon.color="$YELLOW" label="!" \
                --remove '/github.notification\.*/' > /dev/null
}

gh_api_json() {
  local response
  response="$("$GH" api "$1" 2>/dev/null)" || return 1
  printf '%s' "$response" | jq -e . >/dev/null 2>&1 || return 1
  printf '%s' "$response"
}

html_url_for() {
  # Derive the web URL from the notification's own API URL instead of an extra
  # `gh api` round-trip per notification. With a full inbox that N+1 made the
  # plugin take ~40s on every run (and hammered the API every 180s).
  # https://api.github.com/repos/O/R/pulls/N -> https://github.com/O/R/pull/N
  local api_url
  api_url="$(printf '%s' "$1" | sed -e "s/^'//" -e "s/'$//")"
  case "$api_url" in
    *//api.github.com/repos/*)
      printf '%s\n' "$api_url" \
        | sed -e 's#//api\.github\.com/repos/#//github.com/#' \
              -e 's#/pulls/#/pull/#' \
              -e 's#/commits/#/commit/#'
      ;;
    *)
      printf '%s\n' "https://www.github.com/notifications"
      ;;
  esac
}

update() {
  source "$CONFIG_DIR/colors.sh"
  source "$CONFIG_DIR/icons.sh"

  if ! NOTIFICATIONS="$(gh_api_json notifications)" \
    || ! printf '%s' "$NOTIFICATIONS" | jq -e 'type == "array"' >/dev/null 2>&1; then
    set_unavailable
    return
  fi

  COUNT="$(printf '%s' "$NOTIFICATIONS" | jq 'length')"

  args=()
  if [ "$NOTIFICATIONS" = "[]" ]; then
    args+=(--set $NAME icon=$BELL label="0")
  else
    args+=(--set $NAME icon=$BELL_DOT label="$COUNT")
  fi

  PREV_COUNT=$("$SKETCHYBAR" --query github.bell 2>/dev/null | jq -r '.label.value // 0' 2>/dev/null)
  [ -z "$PREV_COUNT" ] && PREV_COUNT=0
  # For sound to play around with:
  # afplay /System/Library/Sounds/Morse.aiff

  args+=(--remove '/github.notification\.*/')

  COUNTER=0
  COLOR=$BLUE
  args+=(--set github.bell icon.color=$COLOR)

  while read -r repo url type title
  do
    COUNTER=$((COUNTER + 1))
    IMPORTANT="$(echo "$title" | egrep -i "(deprecat|break|broke)")"
    COLOR=$BLUE
    PADDING=0

    if [ "${repo}" = "" ] && [ "${title}" = "" ]; then
      repo="Note"
      title="No new notifications"
    fi

    case "${type}" in
      "'Issue'") COLOR=$GREEN; ICON=$GIT_ISSUE; URL="$(html_url_for "$url")"
      ;;
      "'Discussion'") COLOR=$WHITE; ICON=$GIT_DISCUSSION; URL="https://www.github.com/notifications"
      ;;
      "'PullRequest'") COLOR=$MAGENTA; ICON=$GIT_PULL_REQUEST; URL="$(html_url_for "$url")"
      ;;
      "'Commit'") COLOR=$WHITE; ICON=$GIT_COMMIT; URL="$(html_url_for "$url")"
      ;;
    esac

    if [ "$IMPORTANT" != "" ]; then
      COLOR=$RED
      ICON=􀁞
      args+=(--set github.bell icon.color=$COLOR)
    fi

    notification=(
      label="$(echo "$title" | sed -e "s/^'//" -e "s/'$//")"
      icon="$ICON $(echo "$repo" | sed -e "s/^'//" -e "s/'$//"):"
      icon.padding_left="$PADDING"
      label.padding_right="$PADDING"
      icon.color=$COLOR
      position=popup.github.bell
      icon.background.color=$COLOR
      drawing=on
      click_script="open \"$URL\"; \"$SKETCHYBAR\" --set github.bell popup.drawing=off; sleep 5; \"$SKETCHYBAR\" --trigger github.update"
    )

    args+=(--clone github.notification.$COUNTER github.template \
           --set github.notification.$COUNTER "${notification[@]}")
  done <<< "$(printf '%s' "$NOTIFICATIONS" | jq -r '.[] | [.repository.name, .subject.url, .subject.type, .subject.title] | @sh')"

  "$SKETCHYBAR" -m "${args[@]}" > /dev/null

  if [ $COUNT -gt $PREV_COUNT ] 2>/dev/null || [ "$SENDER" = "forced" ]; then
    "$SKETCHYBAR" --animate tanh 15 --set github.bell label.y_offset=5 label.y_offset=0
  fi
}

popup() {
  "$SKETCHYBAR" --set $NAME popup.drawing=$1
}

case "$SENDER" in
  "routine"|"forced"|"github.update") update
  ;;
  "system_woke") sleep 10 && update # Wait for network to connect
  ;;
  "mouse.entered") popup on
  ;;
  "mouse.exited"|"mouse.exited.global") popup off
  ;;
  "mouse.clicked") popup toggle
  ;;
esac
