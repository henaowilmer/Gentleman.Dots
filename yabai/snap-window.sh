#!/usr/bin/env bash

set -euo pipefail

target="${1:-}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

"$script_dir/ensure-managed-window.sh"

# Native yabai BSP placement only. This moves/reflows the managed tree toward
# the requested direction; it does not promise exact geometric grid snapping.
warp() {
  yabai -m window --warp "$1" >/dev/null 2>&1 || true
}

case "$target" in
  left)
    warp west
    ;;
  bottom)
    warp south
    ;;
  top)
    warp north
    ;;
  right)
    warp east
    ;;
  top-left)
    warp north
    warp west
    ;;
  bottom-left)
    warp south
    warp west
    ;;
  bottom-right)
    warp south
    warp east
    ;;
  top-right)
    warp north
    warp east
    ;;
  *)
    exit 64
    ;;
esac
