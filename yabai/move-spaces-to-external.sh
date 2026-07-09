#!/usr/bin/env bash
# Keep only the "social" space (1) on the built-in MacBook display; move every
# other existing space onto a newly connected external display, then remove
# the empty space macOS auto-creates there, so no extra space piles up.
# Triggered by yabai's display_added signal: $YABAI_DISPLAY_INDEX
#
# Relies on every configured space having a stable label (set in yabairc):
# labels survive a --display move even though numeric indices can shift when
# spaces are re-ordered across displays, so we address spaces by label.
set -euo pipefail

target_display="${1:-}"
if [[ -z "$target_display" || ! "$target_display" =~ ^[0-9]+$ ]]; then
	echo "Usage: $0 <display_index>" >&2
	exit 64
fi

command -v yabai >/dev/null 2>&1 || { echo "yabai not found" >&2; exit 127; }
command -v jq >/dev/null 2>&1 || { echo "jq not found" >&2; exit 127; }

# Let yabai finish registering the new display and its auto-created space.
sleep 0.5

yabai -m query --spaces | jq -r --argjson d "$target_display" \
	'.[] | select(.display != $d and .label != "social" and .label != "") | .label' |
while read -r label; do
	[[ -z "$label" ]] && continue
	yabai -m space "$label" --display "$target_display" 2>/dev/null || true
done

sleep 0.2

spaces_json="$(yabai -m query --spaces)"

moved_ok="$(jq -r --argjson d "$target_display" \
	'[.[] | select(.display == $d and .label != "" and .label != null)] | length >= 1' \
	<<<"$spaces_json")"

# Only clean up the leftover auto-created space once we've confirmed at least
# one real (labeled) space actually landed on the target display.
if [[ "$moved_ok" == "true" ]]; then
	jq -r --argjson d "$target_display" \
		'.[] | select(.display == $d and (.windows | length) == 0 and (.label == "" or .label == null)) | .index' \
		<<<"$spaces_json" |
	while read -r idx; do
		[[ -z "$idx" ]] && continue
		yabai -m space "$idx" --destroy 2>/dev/null || true
	done
fi
