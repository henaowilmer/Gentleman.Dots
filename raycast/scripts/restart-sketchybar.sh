#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Reset SketchyBar
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🧰
# @raycast.packageName System

export PATH="$HOME/.local/state/nix/profiles/home-manager/home-path/bin:$PATH"
pkill sketchybar
sleep 1
sketchybar &

echo "SketchyBar reset"
