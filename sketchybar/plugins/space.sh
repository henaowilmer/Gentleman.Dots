#!/bin/bash

# Space/Workspace indicator - zero yabai queries, pure sketchybar state
# Active sector glows electric blue with ice-cyan label

NEON_BLUE=0xff347aff
ICE_CYAN=0xff5ce1ff
GLOW_BLUE_FILL=0x33347aff
DIM=0xff4a5578
ISLAND_BG=0xe6070b1a
ISLAND_BORDER=0xff1c2c54

if [ "$SELECTED" = "true" ]; then
  sketchybar --animate tanh 10 --set $NAME \
    label.color=$ICE_CYAN \
    label.font="IosevkaTerm NF:Bold:12.0" \
    background.color=$GLOW_BLUE_FILL \
    background.border_color=$NEON_BLUE
else
  sketchybar --animate tanh 10 --set $NAME \
    label.color=$DIM \
    label.font="IosevkaTerm NF:Regular:12.0" \
    background.color=$ISLAND_BG \
    background.border_color=$ISLAND_BORDER
fi
