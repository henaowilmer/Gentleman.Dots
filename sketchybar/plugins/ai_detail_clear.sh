#!/bin/bash

# Auto-hide AI detail box after a short delay

sleep 10
sketchybar --set ai_detail drawing=off >/dev/null 2>&1 || true
