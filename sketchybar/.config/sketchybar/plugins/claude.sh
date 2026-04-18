#!/usr/bin/env bash

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

# Claude Code 5-hour session token limit, measured in NON-CACHE tokens
# (input + output only). Anthropic doesn't officially publish these, but
# community-observed per-plan ceilings are approximately:
#   Pro       ~20_000
#   Max 5x    ~100_000
#   Max 20x   ~400_000   <- calibrated to observed usage on this account
# Cache-read tokens are excluded because they dominate raw totals (~99%)
# while Anthropic's rate limiter weighs them far less.
# Override per session via env: CLAUDE_SESSION_TOKEN_LIMIT=…
CLAUDE_SESSION_TOKEN_LIMIT="${CLAUDE_SESSION_TOKEN_LIMIT:-400000}"

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

update() {
  if [ -z "$CCUSAGE" ] || ! command -v "$CCUSAGE" >/dev/null 2>&1; then
    sketchybar --set claude.usage icon=✻ icon.color=$RED label="ccusage?"
    return
  fi

  local blocks
  blocks=$("$CCUSAGE" blocks --active --json -O 2>/dev/null)

  if [ -z "$blocks" ] || [ "$(echo "$blocks" | jq '.blocks | length')" = "0" ]; then
    sketchybar --set claude.usage icon.color=$GREY label="idle"
    render_popup_idle
    return
  fi

  local block cost total_tokens in_tok out_tok cache_tok non_cache used_pct remaining burn_tpm projected_cost color
  block=$(echo "$blocks"      | jq '.blocks[0]')
  cost=$(echo "$block"        | jq -r '.costUSD // 0')
  total_tokens=$(echo "$block" | jq -r '.totalTokens // 0')
  in_tok=$(echo "$block"      | jq -r '.tokenCounts.inputTokens // 0')
  out_tok=$(echo "$block"     | jq -r '.tokenCounts.outputTokens // 0')
  cache_tok=$(echo "$block"   | jq -r '(.tokenCounts.cacheCreationInputTokens // 0) + (.tokenCounts.cacheReadInputTokens // 0)')
  remaining=$(echo "$block"   | jq -r '.projection.remainingMinutes // 0')
  burn_tpm=$(echo "$block"    | jq -r '.burnRate.tokensPerMinute // 0')
  projected_cost=$(echo "$block" | jq -r '.projection.totalCost // 0')

  non_cache=$((in_tok + out_tok))
  used_pct=$(awk -v t="$non_cache" -v l="$CLAUDE_SESSION_TOKEN_LIMIT" 'BEGIN { if (l > 0) printf "%.1f", (t/l)*100; else print "0" }')
  color=$(pct_color "$used_pct")

  local display_pct label
  display_pct=$(awk -v p="$used_pct" 'BEGIN { if (p > 100) printf "100+"; else printf "%.0f", p }')
  if [ "$display_pct" = "100+" ]; then
    label=$(printf "100+%% · %s" "$(fmt_mins "$remaining")")
  else
    label=$(printf "%s%% · %s" "$display_pct" "$(fmt_mins "$remaining")")
  fi

  sketchybar --set claude.usage icon.color="$color" label="$label" label.color="$color"

  render_popup "$cost" "$total_tokens" "$non_cache" "$cache_tok" "$used_pct" "$remaining" "$burn_tpm" "$projected_cost"
}

render_popup_idle() {
  local today today_cost today_tokens
  today=$("$CCUSAGE" daily --json -o desc -O 2>/dev/null | jq '.daily[0] // empty')
  today_cost=$(echo "$today" | jq -r '.totalCost // 0')
  today_tokens=$(echo "$today" | jq -r '.totalTokens // 0')

  build_popup_rows \
    "Session"       "no active block" "$GREY" \
    "Today cost"    "$(fmt_money "$today_cost")" "$WHITE" \
    "Today tokens"  "$(fmt_tokens "$today_tokens")" "$WHITE"
}

render_popup() {
  local cost=$1 total=$2 non_cache=$3 cache=$4 used_pct=$5 remaining=$6 burn=$7 pcost=$8

  local today today_cost today_tokens yest_cost yest_tokens week_cost
  today=$("$CCUSAGE" daily --json -o desc -O 2>/dev/null)
  today_cost=$(echo "$today"  | jq -r '.daily[0].totalCost // 0')
  today_tokens=$(echo "$today" | jq -r '.daily[0].totalTokens // 0')
  yest_cost=$(echo "$today"   | jq -r '.daily[1].totalCost // 0')
  yest_tokens=$(echo "$today" | jq -r '.daily[1].totalTokens // 0')
  week_cost=$(echo "$today"   | jq -r '[.daily[0:7][].totalCost] | add // 0')

  local used_color
  used_color=$(pct_color "$used_pct")

  build_popup_rows \
    "Session cost"     "$(fmt_money "$cost")"                                         "$WHITE"      \
    "Non-cache used"   "$(fmt_tokens "$non_cache") / $(fmt_tokens "$CLAUDE_SESSION_TOKEN_LIMIT")"  "$used_color" \
    "Session %"        "$(printf "%.1f%%" "$used_pct")"                               "$used_color" \
    "Cache tokens"     "$(fmt_tokens "$cache")"                                       "$GREY"       \
    "Time left"        "$(fmt_mins "$remaining")"                                     "$WHITE"      \
    "Burn rate"        "$(fmt_tokens "$burn")/min"                                    "$WHITE"      \
    "Projected cost"   "$(fmt_money "$pcost")"                                        "$YELLOW"     \
    "Today"            "$(fmt_money "$today_cost") · $(fmt_tokens "$today_tokens")"   "$WHITE"      \
    "Yesterday"        "$(fmt_money "$yest_cost") · $(fmt_tokens "$yest_tokens")"     "$GREY"       \
    "Last 7 days"      "$(fmt_money "$week_cost")"                                    "$BLUE"
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
    update
    popup toggle
    ;;
  "mouse.exited.global")
    popup off
    ;;
  *)
    update
    ;;
esac
