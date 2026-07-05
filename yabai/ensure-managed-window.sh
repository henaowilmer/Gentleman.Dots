#!/usr/bin/env bash

set -euo pipefail

if ! command -v yabai >/dev/null 2>&1; then
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  exit 1
fi

window_json="$(yabai -m query --windows --window 2>/dev/null)" || exit 1

is_floating="$(jq -r '."is-floating" // false' <<<"$window_json")"
if [[ "$is_floating" == "true" ]]; then
  yabai -m window --toggle float >/dev/null 2>&1 || exit 1
fi

exit 0
