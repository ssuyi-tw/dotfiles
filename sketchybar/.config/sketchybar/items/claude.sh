#!/bin/bash

source "$HOME/.config/sketchybar/colors.sh"
source "$CONFIG_DIR/icons.sh"

POPUP_CLICK_SCRIPT="$PLUGIN_DIR/claude.sh"

claude_usage=(
  script="$PLUGIN_DIR/claude.sh"
  click_script="$POPUP_CLICK_SCRIPT"
  update_freq=60
  icon=
  icon.font="Font Awesome 7 Brands:Regular:15.0"
  icon.color=$BRIGHT_ORANGE
  icon.padding_left=4
  icon.padding_right=4
  label="…"
  label.color=$WHITE
  popup.align=right
  popup.horizontal=off
)

claude_row=(
  drawing=off
  background.corner_radius=6
  background.height=22
  padding_left=8
  padding_right=8
  icon.font="$FONT:Semibold:12.0"
  label.font="$FONT:Semibold:12.0"
  label.padding_left=10
  icon.padding_right=10
  icon.color=$WHITE
  label.color=$WHITE
  width=320
)

sketchybar --add item claude.usage right                     \
           --set       claude.usage "${claude_usage[@]}"     \
           --subscribe claude.usage mouse.clicked            \
                                    mouse.exited.global      \
                                    system_woke              \
                                                             \
           --add item claude.row popup.claude.usage          \
           --set      claude.row "${claude_row[@]}"
