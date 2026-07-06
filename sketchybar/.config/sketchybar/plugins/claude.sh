#!/usr/bin/env bash

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

# Cache the authoritative /oauth/usage response to stay under Anthropic's
# endpoint rate limit (Claude Code itself gets 429 at sub-second polls).
USAGE_CACHE="${TMPDIR:-/tmp}/claude_usage_oauth.json"
USAGE_CACHE_TTL=55

CCUSAGE=$(command -v ccusage || echo "$HOME/.nvm/versions/node/v22.21.1/bin/ccusage")

popup() {
  sketchybar --set claude.usage popup.drawing="$1"
}

fmt_money() {
  awk -v v="$1" 'BEGIN { printf "$%.2f", v }'
}

fmt_tokens() {
  awk -v v="$1" 'BEGIN {
    if (v >= 1e6) printf "%.2fM", v/1e6;
    else if (v >= 1e3) printf "%.1fk", v/1e3;
    else printf "%d", v;
  }'
}

fmt_mins() {
  awk -v v="$1" 'BEGIN {
    if (v <= 0) { print "0m"; exit }
    h = int(v/60); m = int(v%60);
    if (h > 0) printf "%dh %dm", h, m;
    else printf "%dm", m;
  }'
}

pct_color() {
  awk -v p="$1" -v g="$GREEN" -v y="$YELLOW" -v o="$ORANGE" -v r="$RED" 'BEGIN {
    if (p >= 100) print r;
    else if (p >= 80) print o;
    else if (p >= 50) print y;
    else print g;
  }'
}

# mins from an ISO-8601 timestamp to now (positive if in the future).
mins_until() {
  local iso="$1"
  [ -z "$iso" ] || [ "$iso" = "null" ] && { echo 0; return; }
  python3 -c "
import sys, datetime
s = sys.argv[1].replace('Z','+00:00')
t = datetime.datetime.fromisoformat(s)
now = datetime.datetime.now(datetime.timezone.utc)
print(max(0, int((t - now).total_seconds() // 60)))
" "$iso" 2>/dev/null || echo 0
}

fetch_usage() {
  if [ -f "$USAGE_CACHE" ]; then
    local age
    age=$(( $(date +%s) - $(stat -f %m "$USAGE_CACHE" 2>/dev/null || echo 0) ))
    if [ "$age" -lt "$USAGE_CACHE_TTL" ]; then
      cat "$USAGE_CACHE"
      return 0
    fi
  fi

  local tok
  tok=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
        | jq -r '.claudeAiOauth.accessToken // empty')
  [ -z "$tok" ] && return 1

  local body status
  body=$(curl -sS -m 5 -w "\n%{http_code}" \
    -H "Authorization: Bearer $tok" \
    -H "anthropic-beta: oauth-2025-04-20" \
    "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
  status=$(echo "$body" | tail -n1)
  body=$(echo "$body" | sed '$d')

  if [ "$status" = "200" ]; then
    printf '%s' "$body" >"$USAGE_CACHE"
    printf '%s' "$body"
    return 0
  fi
  # On 429/401/etc. fall back to stale cache if we have one.
  [ -f "$USAGE_CACHE" ] && cat "$USAGE_CACHE" && return 0
  return 1
}

update() {
  local usage
  if ! usage=$(fetch_usage) || [ -z "$usage" ]; then
    sketchybar --set claude.usage icon=✻ icon.color=$RED label="auth?"
    return
  fi

  local sess_pct sess_reset sess_remaining
  sess_pct=$(echo "$usage" | jq -r '.five_hour.utilization // 0')
  sess_reset=$(echo "$usage" | jq -r '.five_hour.resets_at // ""')
  sess_remaining=$(mins_until "$sess_reset")

  local color display_pct label
  color=$(pct_color "$sess_pct")
  display_pct=$(awk -v p="$sess_pct" 'BEGIN { if (p >= 100) printf "100+"; else printf "%.0f", p }')
  if [ "$display_pct" = "100+" ]; then
    label=$(printf "100+%% · %s" "$(fmt_mins "$sess_remaining")")
  else
    label=$(printf "%s%% · %s" "$display_pct" "$(fmt_mins "$sess_remaining")")
  fi

  sketchybar --set claude.usage icon.color="$color" label="$label" label.color="$color"

  # render_popup shells out to ccusage twice (~8s of Node startup). Only pay for
  # it when the popup is actually being opened, not on every routine label update.
  [ "$1" = "with_popup" ] && render_popup "$usage" "$sess_pct" "$sess_remaining"
}

render_popup() {
  local usage=$1 sess_pct=$2 sess_remaining=$3

  local week_pct week_sonnet week_opus sess_color week_color
  week_pct=$(echo "$usage"    | jq -r '.seven_day.utilization // 0')
  week_sonnet=$(echo "$usage" | jq -r '.seven_day_sonnet.utilization // empty')
  week_opus=$(echo "$usage"   | jq -r '.seven_day_opus.utilization // empty')
  sess_color=$(pct_color "$sess_pct")
  week_color=$(pct_color "$week_pct")

  local block cost billable burn_tpm projected_cost
  block=$("$CCUSAGE" blocks --active --json -O 2>/dev/null | jq '.blocks[0] // empty')
  if [ -n "$block" ]; then
    cost=$(echo "$block"       | jq -r '.costUSD // 0')
    billable=$(echo "$block"   | jq -r '(.tokenCounts.inputTokens // 0) + (.tokenCounts.outputTokens // 0) + (.tokenCounts.cacheCreationInputTokens // 0)')
    burn_tpm=$(echo "$block"   | jq -r '.burnRate.tokensPerMinute // 0')
    projected_cost=$(echo "$block" | jq -r '.projection.totalCost // 0')
  else
    cost=0; billable=0; burn_tpm=0; projected_cost=0
  fi

  local today today_cost today_tokens yest_cost yest_tokens week_cost
  today=$("$CCUSAGE" daily --json -o desc -O 2>/dev/null)
  today_cost=$(echo "$today"   | jq -r '.daily[0].totalCost // 0')
  today_tokens=$(echo "$today" | jq -r '.daily[0].totalTokens // 0')
  yest_cost=$(echo "$today"    | jq -r '.daily[1].totalCost // 0')
  yest_tokens=$(echo "$today"  | jq -r '.daily[1].totalTokens // 0')
  week_cost=$(echo "$today"    | jq -r '[.daily[0:7][].totalCost] | add // 0')

  local rows=(
    "5-hour session"   "$(printf "%.0f%% · %s" "$sess_pct" "$(fmt_mins "$sess_remaining")")" "$sess_color"
    "Weekly all"       "$(printf "%.0f%%" "$week_pct")"                                      "$week_color"
  )
  [ -n "$week_opus" ]   && rows+=("Weekly Opus"   "$(printf "%.0f%%" "$week_opus")"   "$(pct_color "$week_opus")")
  [ -n "$week_sonnet" ] && rows+=("Weekly Sonnet" "$(printf "%.0f%%" "$week_sonnet")" "$(pct_color "$week_sonnet")")
  rows+=(
    "Session cost"     "$(fmt_money "$cost")"                                           "$WHITE"
    "Session tokens"   "$(fmt_tokens "$billable")"                                      "$GREY"
    "Burn rate"        "$(fmt_tokens "$burn_tpm")/min"                                  "$WHITE"
    "Projected cost"   "$(fmt_money "$projected_cost")"                                 "$YELLOW"
    "Today"            "$(fmt_money "$today_cost") · $(fmt_tokens "$today_tokens")"     "$WHITE"
    "Yesterday"        "$(fmt_money "$yest_cost") · $(fmt_tokens "$yest_tokens")"       "$GREY"
    "Last 7 days"      "$(fmt_money "$week_cost")"                                      "$BLUE"
  )
  build_popup_rows "${rows[@]}"
}

build_popup_rows() {
  local args=(--remove '/claude.row\..*/')
  local i=0
  while [ $# -ge 3 ]; do
    local title=$1 value=$2 color=$3
    shift 3
    args+=(--clone "claude.row.$i" claude.row \
           --set   "claude.row.$i" drawing=on \
                                   icon="$title" \
                                   label="$value" \
                                   icon.color="$color" \
                                   label.color="$color" \
                                   position=popup.claude.usage)
    i=$((i + 1))
  done
  sketchybar -m "${args[@]}" > /dev/null
}

case "$SENDER" in
  "mouse.clicked")
    update with_popup
    popup toggle
    ;;
  "mouse.exited.global")
    popup off
    ;;
  *)
    update
    ;;
esac
