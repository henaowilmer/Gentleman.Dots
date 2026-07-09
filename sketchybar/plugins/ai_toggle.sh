#!/bin/bash

# Toggle visibility of OpenAI + OpenCode Go quota panels (Claude and Copilot stay visible)
# State persists across sketchybar reloads via cache file
# ai_hidden_gap spacer keeps separation correct while hidden

NEON_BLUE=0xff347aff
DIM=0xff4a5578

STATE_DIR="$HOME/.cache/sketchybar"
STATE_FILE="$STATE_DIR/ai_quota_hidden"

ICON_VISIBLE="󰚩"
ICON_HIDDEN="󱚧"

ITEMS=(opencode_quota opencode_quota_separator opencode_quota_weekly opencode_box openai_quota openai_quota_separator openai_quota_weekly openai_box ai_provider_gap ai_provider_gap2)

apply_state() {
  local args=()
  local item

  if [ -f "$STATE_FILE" ]; then
    for item in "${ITEMS[@]}"; do
      args+=(--set "$item" drawing=off)
    done
    args+=(--set ai_hidden_gap drawing=on)
    args+=(--set ai_toggle icon="$ICON_HIDDEN" icon.color=$DIM background.border_color=$DIM)
  else
    for item in "${ITEMS[@]}"; do
      args+=(--set "$item" drawing=on)
    done
    args+=(--set ai_hidden_gap drawing=off)
    args+=(--set ai_toggle icon="$ICON_VISIBLE" icon.color=$NEON_BLUE background.border_color=0x99347aff)
  fi

  sketchybar "${args[@]}" >/dev/null 2>&1 || true
}

case "$1" in
  toggle)
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    if [ -f "$STATE_FILE" ]; then
      rm -f "$STATE_FILE"
    else
      touch "$STATE_FILE"
    fi
    apply_state
    ;;
  *)
    apply_state
    ;;
esac
