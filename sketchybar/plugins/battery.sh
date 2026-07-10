#!/bin/bash

# Battery - displays battery percentage with dynamic icon and color

PERCENTAGE=$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)
CHARGING=$(pmset -g batt | grep 'AC Power')

if [ -z "$PERCENTAGE" ]; then
  sketchybar --set $NAME drawing=off
  exit 0
fi

# Determine icon and color based on level
if [ -n "$CHARGING" ]; then
  ICON="󰂄"
  COLOR=0xff347aff
elif [ "$PERCENTAGE" -ge 80 ]; then
  ICON="󰁹"
  COLOR=0xff4dff88
elif [ "$PERCENTAGE" -ge 60 ]; then
  ICON="󰂁"
  COLOR=0xff4dff88
elif [ "$PERCENTAGE" -ge 40 ]; then
  ICON="󰁿"
  COLOR=0xffffd23d
elif [ "$PERCENTAGE" -ge 20 ]; then
  ICON="󰁼"
  COLOR=0xffff3d81
else
  ICON="󰂃"
  COLOR=0xffff3d81
fi

sketchybar --set $NAME icon="$ICON" icon.color="$COLOR" label="${PERCENTAGE}%"
