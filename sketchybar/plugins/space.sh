#!/bin/bash

# Space/Workspace indicator - zero yabai queries, pure sketchybar state
# Active sector glows electric blue with ice-cyan label

# CONFIG_DIR is supplied by SketchyBar at runtime.
# shellcheck disable=SC1091
source "$CONFIG_DIR/theme.sh"

if [ "$SELECTED" = "true" ]; then
  sketchybar --animate tanh 10 --set "$NAME" \
    label.color="$WORKSPACE_ACTIVE" \
    label.font="IosevkaTerm NF:Bold:12.0" \
    background.color="$SELECTED_BG" \
    background.border_color="$WORKSPACE_BORDER"
else
  sketchybar --animate tanh 10 --set "$NAME" \
    label.color="$DIM" \
    label.font="IosevkaTerm NF:Regular:12.0" \
    background.color="$ISLAND_BG" \
    background.border_color="$ISLAND_BORDER"
fi
