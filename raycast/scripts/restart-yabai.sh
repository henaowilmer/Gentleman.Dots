#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Restart Yabai
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🔄
# @raycast.packageName System

set -euo pipefail

uid="$(/usr/bin/id -u)"
label="com.asmvik.yabai"
domain="gui/${uid}"
plist="$HOME/Library/LaunchAgents/${label}.plist"

# Prefer yabai's built-in service manager used by this repo.
if command -v yabai >/dev/null 2>&1; then
  if pgrep -x yabai >/dev/null 2>&1; then
    yabai --restart-service
  else
    yabai --start-service
  fi

  echo "Yabai restarted"
  exit 0
fi

# Fallback for setups that still manage yabai with launchctl directly.
if [ ! -f "$plist" ]; then
  echo "Missing yabai LaunchAgent: $plist"
  echo "Install/start yabai first (e.g. run ~/bin/install-yabai or home-manager switch)."
  exit 1
fi

if /bin/launchctl print "${domain}/${label}" >/dev/null 2>&1; then
  /bin/launchctl kickstart -k "${domain}/${label}"
else
  /bin/launchctl bootstrap "$domain" "$plist"
fi

echo "Yabai restarted"
