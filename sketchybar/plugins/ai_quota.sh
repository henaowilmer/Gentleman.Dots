#!/bin/bash

# AI quota - provider-specific quota labels from opencode-quota cache

GREEN=0xff4dff88
YELLOW=0xffffd23d
RED=0xffff3d81
DIM=0xff4a5578
WHITE=0xffdbe9ff
ORANGE=0xffff9f1c
COPILOT_BLUE=0xff347aff
OC_GO_GREEN=0xff4dff88
OC_GO_ICON=0xffdbe9ff

export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:$HOME/.local/state/nix/profiles/home-manager/home-path/bin:$HOME/.nix-profile/bin"

is_pct_mode() {
  case "$1" in
    openai|claude|anthropic|opencode-go|opencodego|opencode_go) return 0 ;;
    *) return 1 ;;
  esac
}

MODE="${1:-openai}"
ACTION="auto"
WINDOW="primary"
REFRESHING=0

for arg in "${@:2}"; do
  case "$arg" in
    click)
      ACTION="click"
      ;;
    weekly|secondary)
      WINDOW="weekly"
      ;;
    primary|5h)
      WINDOW="primary"
      ;;
  esac
done

if [ "$ACTION" = "click" ]; then
  REFRESHING=1
fi

QUOTA_BIN="${OPENCODE_QUOTA_BIN:-$HOME/.config/opencode/node_modules/.bin/opencode-quota}"
JQ_BIN="$(command -v jq 2>/dev/null || true)"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar"
CACHE_FILE="$CACHE_DIR/ai_quota_${MODE}_${WINDOW}.state"
DETAIL_CACHE_FILE="$CACHE_DIR/ai_quota_${MODE}.detail"
CLAUDE_RATE_LIMITS_FILE="$CACHE_DIR/claude-rate-limits.json"
CLAUDE_USAGE_FILE="$HOME/.claude.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

atomic_write() {
  local target="$1"
  local value="$2"
  local temp

  (umask 077 && mkdir -p "$CACHE_DIR") 2>/dev/null || return
  temp="$(mktemp "$target.XXXXXX")" || return
  chmod 600 "$temp" 2>/dev/null || {
    rm -f "$temp"
    return
  }
  if ! printf '%s\n' "$value" > "$temp"; then
    rm -f "$temp"
    return
  fi
  mv -f "$temp" "$target"
}

read_cache() {
  if [ -f "$CACHE_FILE" ]; then
    cat "$CACHE_FILE" 2>/dev/null
  fi
}

write_cache() {
  local color="$1"
  local label="$2"
  atomic_write "$CACHE_FILE" "$color|$label" 2>/dev/null || true
}

read_detail_cache() {
  if [ -f "$DETAIL_CACHE_FILE" ]; then
    cat "$DETAIL_CACHE_FILE" 2>/dev/null
  fi
}

mode_source_item() {
  case "$MODE" in
    openai)
      printf -- "openai_quota"
      ;;
    anthropic|claude)
      printf -- "claude_quota"
      ;;
    copilot)
      printf -- "copilot_quota"
      ;;
    opencode-go|opencodego|opencode_go)
      printf -- "opencode_quota"
      ;;
    *)
      printf -- ""
      ;;
  esac
}

# Container box whose glow border color the detail box should mirror
mode_box_item() {
  case "$MODE" in
    openai)
      printf -- "openai_box"
      ;;
    anthropic|claude)
      printf -- "claude_box"
      ;;
    copilot)
      printf -- "copilot_quota"
      ;;
    opencode-go|opencodego|opencode_go)
      printf -- "opencode_box"
      ;;
    *)
      printf -- ""
      ;;
  esac
}

set_detail_with_source_style() {
  local message="$1"
  local source_item
  local icon_value
  local icon_color
  local icon_font

  local box_item
  local border_color

  source_item="$(mode_source_item)"
  box_item="$(mode_box_item)"
  icon_value=""
  icon_color="$WHITE"
  icon_font="IosevkaTerm NF:Bold:14.0"
  border_color=""

  if [ -n "$source_item" ]; then
    icon_value="$(sketchybar --query "$source_item" 2>/dev/null | "$JQ_BIN" -r '.icon.value // empty' 2>/dev/null)"
    icon_color="$(sketchybar --query "$source_item" 2>/dev/null | "$JQ_BIN" -r '.icon.color // empty' 2>/dev/null)"
    icon_font="$(sketchybar --query "$source_item" 2>/dev/null | "$JQ_BIN" -r '.icon.font // empty' 2>/dev/null)"
  fi

  if [ -n "$box_item" ]; then
    border_color="$(sketchybar --query "$box_item" 2>/dev/null | "$JQ_BIN" -r '.geometry.background.border_color // empty' 2>/dev/null)"
  fi

  if [ -z "$icon_color" ]; then
    icon_color="$WHITE"
  fi
  if [ -z "$icon_font" ]; then
    icon_font="IosevkaTerm NF:Bold:14.0"
  fi
  if [ -z "$border_color" ]; then
    border_color="$icon_color"
  fi

  sketchybar --set ai_detail drawing=on icon.drawing=on icon="$icon_value" icon.color="$icon_color" icon.font="$icon_font" label="$message" label.color="$WHITE" background.border_color="$border_color" >/dev/null 2>&1 || true
}

write_detail_cache() {
  local detail="$1"
  if [ -z "$detail" ]; then
    return
  fi
  atomic_write "$DETAIL_CACHE_FILE" "$detail" 2>/dev/null || true
}

set_item() {
  local icon_color="$1"
  local label="$2"
  local label_color="${3:-$WHITE}"
  sketchybar --set "$NAME" icon.color="$icon_color" label="$label" label.color="$label_color"
  if [ "$label" != "--" ]; then
    write_cache "$icon_color" "$label"
  fi
}

mode_icon_color() {
  case "$MODE" in
    openai)
      printf -- "%s" "$WHITE"
      ;;
    anthropic|claude)
      printf -- "%s" "$ORANGE"
      ;;
    copilot)
      printf -- "%s" "$COPILOT_BLUE"
      ;;
    opencode-go|opencodego|opencode_go)
      printf -- "%s" "$OC_GO_ICON"
      ;;
    *)
      printf -- ""
      ;;
  esac
}

show_refresh_feedback() {
  if [ "$REFRESHING" -eq 1 ] && [ -n "$NAME" ]; then
    sketchybar --set "$NAME" label.color="$YELLOW"
    sleep 0.12
  fi
}

show_detail_box() {
  local message="$1"
  if [ "$REFRESHING" -eq 1 ]; then
    set_detail_with_source_style "$message"
    write_detail_cache "$message"
    "$SCRIPT_DIR/ai_detail_clear.sh" >/dev/null 2>&1 &
  fi
}

show_cached_detail_box() {
  local cached
  cached="$(read_detail_cache)"
  if [ "$REFRESHING" -eq 1 ] && [ -n "$cached" ]; then
    set_detail_with_source_style "$cached"
    "$SCRIPT_DIR/ai_detail_clear.sh" >/dev/null 2>&1 &
    return 0
  fi
  return 1
}

show_unavailable_detail() {
  local message="$1"
  if [ "$REFRESHING" -eq 1 ]; then
    set_detail_with_source_style "$message"
    sketchybar --set ai_detail label.color="$YELLOW" >/dev/null 2>&1 || true
    "$SCRIPT_DIR/ai_detail_clear.sh" >/dev/null 2>&1 &
  fi
}

set_fallback() {
  local cached
  local cached_color
  local cached_label
  local current_label
  local current_color
  local current_label_color
  local fixed_icon_color
  local fallback_label_color
  local pct_value

  fixed_icon_color="$(mode_icon_color)"

  if [ -n "$NAME" ]; then
    current_label="$(sketchybar --query "$NAME" 2>/dev/null | "$JQ_BIN" -r '.label.value // empty' 2>/dev/null)"
    current_color="$(sketchybar --query "$NAME" 2>/dev/null | "$JQ_BIN" -r '.icon.color // empty' 2>/dev/null)"
    current_label_color="$(sketchybar --query "$NAME" 2>/dev/null | "$JQ_BIN" -r '.label.color // empty' 2>/dev/null)"
  fi

  cached="$(read_cache)"
  if [ -n "$cached" ]; then
    cached_color="${cached%%|*}"
    cached_label="${cached#*|}"
    if is_pct_mode "$MODE"; then
      case "$cached_label" in
        *" | "*) cached_label="" ;;
      esac
    fi
    if [ "$WINDOW" = "weekly" ] && { is_pct_mode "$MODE"; }; then
      cached_label="${cached_label#| }"
      cached_label="${cached_label#|}"
    fi
    if [ -n "$cached_color" ] && [ -n "$cached_label" ] && [ "$cached_label" != "$cached" ]; then
      fallback_label_color="${current_label_color:-$WHITE}"
      if is_pct_mode "$MODE"; then
        pct_value="${cached_label%%%}"
        case "$pct_value" in
          ''|*[!0-9]*) ;;
          *) fallback_label_color="$(pick_color_by_pct "$pct_value")" ;;
        esac
      fi
      sketchybar --set "$NAME" icon.color="${fixed_icon_color:-$cached_color}" label="$cached_label" label.color="$fallback_label_color"
      return
    fi
  fi

  if [ -n "$NAME" ]; then
    if is_pct_mode "$MODE"; then
      case "$current_label" in
        *" | "*) current_label="" ;;
      esac
      if [ "$WINDOW" = "weekly" ]; then
        case "$current_label" in
          "| "*) current_label="${current_label#| }" ;;
          "|"*) current_label="${current_label#|}" ;;
        esac
      fi
    fi
    if [ -n "$current_label" ] && [ "$current_label" != "--" ]; then
      fallback_label_color="${current_label_color:-$WHITE}"
      if is_pct_mode "$MODE"; then
        pct_value="${current_label%%%}"
        case "$pct_value" in
          ''|*[!0-9]*) ;;
          *) fallback_label_color="$(pick_color_by_pct "$pct_value")" ;;
        esac
      fi
      sketchybar --set "$NAME" icon.color="${fixed_icon_color:-${current_color:-$DIM}}" label="$current_label" label.color="$fallback_label_color"
      return
    fi
  fi

  case "$MODE" in
    openai)
      if [ "$WINDOW" = "weekly" ]; then
        sketchybar --set "$NAME" icon.color="$WHITE" label="--" label.color="$DIM"
      else
        sketchybar --set "$NAME" icon.color="$WHITE" label="--" label.color="$DIM"
      fi
      ;;
    anthropic|claude)
      if [ "$WINDOW" = "weekly" ]; then
        sketchybar --set "$NAME" icon.color="$ORANGE" label="--" label.color="$DIM"
      else
        sketchybar --set "$NAME" icon.color="$ORANGE" label="--" label.color="$DIM"
      fi
      ;;
    copilot)
      sketchybar --set "$NAME" icon.color="$COPILOT_BLUE" label="--" label.color="$DIM"
      ;;
    opencode-go|opencodego|opencode_go)
      sketchybar --set "$NAME" icon.color="$OC_GO_ICON" label="--" label.color="$DIM"
      ;;
    *)
      sketchybar --set "$NAME" icon.color="$DIM" label="--" label.color="$DIM"
      ;;
  esac
}

fmt_pct() {
  local raw="$1"
  if [ -z "$raw" ] || [ "$raw" = "null" ]; then
    printf -- "--"
  else
    printf -- "%s" "$raw" | awk '{ printf "%d", $1 }'
  fi
}

fmt_reset_remaining() {
  local reset_at="$1"
  local cleaned
  local now diff days hours mins

  if [ -z "$reset_at" ] || [ "$reset_at" = "null" ]; then
    printf -- "--"
    return
  fi

  if ! printf '%s' "$reset_at" | grep -Eq '^[0-9]+$'; then
    if command -v python3 >/dev/null 2>&1; then
      reset_at="$(python3 - "$reset_at" <<'PY'
import sys
from datetime import datetime

value = sys.argv[1].strip()
if not value:
    raise SystemExit(0)

normalized = value.replace("Z", "+00:00")
try:
    dt = datetime.fromisoformat(normalized)
except ValueError:
    raise SystemExit(0)

print(int(dt.timestamp()))
PY
      )"
    else
      reset_at=""
    fi
  fi

  if [ -z "$reset_at" ] || ! printf '%s' "$reset_at" | grep -Eq '^[0-9]+$'; then
    printf -- "--"
    return
  fi

  now="${AI_QUOTA_NOW:-$(date +%s)}"
  diff=$((reset_at - now))

  if [ "$diff" -le 0 ]; then
    printf -- "now"
    return
  fi

  days=$((diff / 86400))
  hours=$(((diff % 86400) / 3600))
  mins=$(((diff % 3600) / 60))

  if [ "$days" -gt 0 ]; then
    printf -- "%dd %dh" "$days" "$hours"
  elif [ "$hours" -gt 0 ]; then
    printf -- "%dh %dm" "$hours" "$mins"
  else
    printf -- "%dm" "$mins"
  fi
}

pick_color_by_pct() {
  local pct="$1"
  if [ "$pct" = "--" ]; then
    printf -- "%s" "$DIM"
  elif [ "$pct" -lt 20 ]; then
    printf -- "%s" "$RED"
  elif [ "$pct" -lt 40 ]; then
    printf -- "%s" "$YELLOW"
  else
    printf -- "%s" "$WHITE"
  fi
}

# When the current read is unavailable (e.g. a forced click-refresh that gets
# rate-limited), the sibling weekly panel must NOT be blanked to "--": that
# would wipe a value the weekly script already fetched. Restore it from its own
# weekly cache instead, and only fall back to "--" when no cache exists.
restore_sibling_weekly() {
  local item="$1"
  local weekly_cache="$CACHE_DIR/ai_quota_${MODE}_weekly.state"
  local cached cached_label pct color

  if [ -f "$weekly_cache" ]; then
    cached="$(cat "$weekly_cache" 2>/dev/null)"
    cached_label="${cached#*|}"
    if [ -n "$cached_label" ] && [ "$cached_label" != "$cached" ] && [ "$cached_label" != "--" ]; then
      color="$WHITE"
      pct="${cached_label%%%}"
      case "$pct" in
        ''|*[!0-9]*) ;;
        *) color="$(pick_color_by_pct "$pct")" ;;
      esac
      sketchybar --set "$item" label="$cached_label" label.color="$color" >/dev/null 2>&1 || true
      return 0
    fi
  fi

  sketchybar --set "$item" label="--" label.color="$DIM" >/dev/null 2>&1 || true
  return 1
}

write_sibling_weekly_cache() {
  local color="$1"
  local label="$2"
  local weekly_cache="$CACHE_DIR/ai_quota_${MODE}_weekly.state"

  if [ "$label" = "--" ]; then
    return
  fi

  atomic_write "$weekly_cache" "$color|$label" 2>/dev/null || true
}

mark_claude_unavailable() {
  local reason="$1"
  local item label

  set_fallback
  restore_sibling_weekly claude_quota_weekly

  for item in claude_quota claude_quota_weekly; do
    label="$(sketchybar --query "$item" 2>/dev/null | "$JQ_BIN" -r '.label.value // empty' 2>/dev/null)"
    label="${label%!}"
    if [ -z "$label" ] || [ "$label" = "--" ]; then
      label="--"
    fi
    sketchybar --set "$item" label="${label}!" label.color="$YELLOW" >/dev/null 2>&1 || true
  done

  show_unavailable_detail "unavailable ($reason)"
}

# Global visibility toggle owned by ai_toggle.sh. When present, every AI panel
# is hidden and per-provider layout logic must not re-draw anything.
HIDDEN_STATE_FILE="$CACHE_DIR/ai_quota_hidden"

# OpenAI (Plus) currently exposes only a weekly window; its API stopped sending
# the 5h window (secondary_window: null). When there is no 5h value, collapse the
# box to a single weekly panel instead of duplicating the weekly number in both
# the primary and weekly slots. When OpenAI restores the 5h window, the split
# view returns automatically with no further changes.
apply_openai_split_layout() {
  local five_h="$1"

  # Never fight the global hide/show toggle.
  if [ -f "$HIDDEN_STATE_FILE" ]; then
    return
  fi

  if [ "$five_h" != "--" ]; then
    sketchybar --set openai_quota_separator drawing=on \
               --set openai_quota_weekly drawing=on >/dev/null 2>&1 || true
  else
    sketchybar --set openai_quota_separator drawing=off \
               --set openai_quota_weekly drawing=off >/dev/null 2>&1 || true
  fi
}

parse_reset_epoch() {
  local value="$1"

  if printf '%s' "$value" | grep -Eq '^[0-9]+$'; then
    printf '%s' "$value"
    return
  fi

  command -v python3 >/dev/null 2>&1 || return
  python3 - "$value" <<'PY'
import sys
from datetime import datetime

try:
    value = sys.argv[1].replace("Z", "+00:00")
    print(int(datetime.fromisoformat(value).timestamp()))
except (ValueError, OverflowError):
    pass
PY
}

valid_percentage() {
  printf '%s' "$1" | "$JQ_BIN" -eR 'tonumber | isfinite and . >= 0 and . <= 100' >/dev/null 2>&1
}

valid_epoch() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
  esac
  [ "$1" -gt 0 ] && [ "$1" -le 32503680000 ]
}

load_claude_candidate() {
  local kind="$1"
  local window="$2"
  local file captured used reset

  if [ "$kind" = "status-line" ]; then
    file="$CLAUDE_RATE_LIMITS_FILE"
    [ -f "$file" ] || return 1
    captured="$("$JQ_BIN" -r '.captured_at // empty' "$file" 2>/dev/null)"
    used="$("$JQ_BIN" -r --arg window "$window" '.[$window].used_percentage // empty' "$file" 2>/dev/null)"
    reset="$("$JQ_BIN" -r --arg window "$window" '.[$window].resets_at // empty' "$file" 2>/dev/null)"
  else
    file="$CLAUDE_USAGE_FILE"
    [ -f "$file" ] || return 1
    captured="$("$JQ_BIN" -r '.cachedUsageUtilization.fetchedAtMs // empty | if type == "number" then (floor / 1000 | floor) else empty end' "$file" 2>/dev/null)"
    used="$("$JQ_BIN" -r --arg window "$window" '.cachedUsageUtilization.utilization[$window].utilization // empty' "$file" 2>/dev/null)"
    reset="$("$JQ_BIN" -r --arg window "$window" '.cachedUsageUtilization.utilization[$window].resets_at // empty' "$file" 2>/dev/null)"
    reset="$(parse_reset_epoch "$reset")"
  fi

  valid_percentage "$used" || return 1
  valid_epoch "$captured" || return 1
  valid_epoch "$reset" || return 1
  [ "$captured" -le $((CLAUDE_NOW + 300)) ] || return 1

  CANDIDATE_REMAINING="$(printf '%s' "$used" | awk '{ printf "%d", 100 - $1 }')"
  CANDIDATE_RESET="$reset"
  CANDIDATE_SOURCE="$kind"
  CANDIDATE_AGE=$((CLAUDE_NOW - captured))
  [ "$CANDIDATE_AGE" -ge 0 ] || CANDIDATE_AGE=0
  return 0
}

read_widget_value() {
  local window="$1"
  local file="$CACHE_DIR/ai_quota_claude_${window}.state"
  local value

  [ -f "$file" ] || return 1
  value="$(cut -d '|' -f 2- "$file" 2>/dev/null)"
  value="${value%!}"
  value="${value%~}"
  value="${value%%%}"
  case "$value" in
    ''|*[!0-9]*) return 1 ;;
  esac
  [ "$value" -le 100 ] || return 1
  printf '%s||widget-cache||old' "$value"
}

select_claude_window() {
  local window="$1"
  local kind old=""

  for kind in status-line claude-cache; do
    if load_claude_candidate "$kind" "$window"; then
      if [ -z "$old" ]; then
        old="$CANDIDATE_REMAINING|$CANDIDATE_RESET|$CANDIDATE_SOURCE|$CANDIDATE_AGE|old"
      fi
      if [ "$CANDIDATE_AGE" -le 3600 ] && [ "$CANDIDATE_RESET" -gt "$CLAUDE_NOW" ]; then
        if [ "$CANDIDATE_AGE" -ge 900 ]; then
          printf '%s|%s|%s|%s|stale' "$CANDIDATE_REMAINING" "$CANDIDATE_RESET" "$CANDIDATE_SOURCE" "$CANDIDATE_AGE"
        else
          printf '%s|%s|%s|%s|fresh' "$CANDIDATE_REMAINING" "$CANDIDATE_RESET" "$CANDIDATE_SOURCE" "$CANDIDATE_AGE"
        fi
        return
      fi
    fi
  done

  if [ -n "$old" ]; then
    printf '%s' "$old"
  else
    read_widget_value "$( [ "$window" = "five_hour" ] && printf primary || printf weekly )" || printf '||||missing'
  fi
}

format_age() {
  local age="$1"
  if [ -z "$age" ]; then
    printf 'unknown age'
  elif [ "$age" -lt 60 ]; then
    printf '%ss old' "$age"
  else
    printf '%sm old' "$((age / 60))"
  fi
}

render_claude_window() {
  local item="$1" result="$2"
  local value reset source age state marker color label
  IFS='|' read -r value reset source age state <<< "$result"

  marker=""
  color="$DIM"
  if [ -n "$value" ]; then
    color="$(pick_color_by_pct "$value")"
    case "$state" in
      stale) marker="~" ; color="$YELLOW" ;;
      old) marker="!" ; color="$YELLOW" ;;
    esac
    label="${value}%${marker}"
    if [ "$state" != "old" ]; then
      CACHE_FILE="$CACHE_DIR/ai_quota_claude_$( [ "$item" = "claude_quota" ] && printf primary || printf weekly ).state"
      write_cache "$ORANGE" "${value}%"
    fi
  else
    label="--!"
    color="$YELLOW"
  fi
  sketchybar --set "$item" icon.color="$ORANGE" label="$label" label.color="$color" >/dev/null 2>&1 || true
}

claude_detail_window() {
  local result="$2"
  local value reset source age state
  IFS='|' read -r value reset source age state <<< "$result"
  if [ -z "$value" ]; then
    printf 'unavailable'
    return
  fi
  if [ -n "$reset" ]; then
    reset="$(fmt_reset_remaining "$reset")"
  else
    reset="unknown"
  fi
  printf '%s%% (%s)' "$value" "$reset"
}

run_claude_local() {
  local primary weekly detail
  CLAUDE_NOW="${AI_QUOTA_NOW:-$(date +%s)}"
  case "$CLAUDE_NOW" in
    ''|*[!0-9]*) CLAUDE_NOW="$(date +%s)" ;;
  esac

  primary="$(select_claude_window five_hour)"
  weekly="$(select_claude_window seven_day)"
  render_claude_window claude_quota "$primary"
  render_claude_window claude_quota_weekly "$weekly"

  if [[ "$primary" == '||||missing' && "$weekly" == '||||missing' ]]; then
    detail="quota unavailable"
  else
    detail="$(claude_detail_window 5h "$primary") | $(claude_detail_window 7d "$weekly")"
  fi
  write_detail_cache "$detail"
  show_detail_box "$detail"
}

if [ -z "$JQ_BIN" ]; then
  set_fallback
  exit 0
fi

show_refresh_feedback

# Claude is intentionally local-only. Return before resolving or invoking
# opencode-quota so periodic updates and clicks can never reach Anthropic.
case "$MODE" in
  anthropic|claude)
    run_claude_local
    exit 0
    ;;
esac

if [ ! -x "$QUOTA_BIN" ]; then
  QUOTA_BIN="$(command -v opencode-quota 2>/dev/null || true)"
fi

if [ -z "$QUOTA_BIN" ]; then
  set_fallback
  exit 0
fi

PROVIDER_ID=""
case "$MODE" in
  openai)
    PROVIDER_ID="openai"
    ;;
  copilot)
    PROVIDER_ID="copilot"
    ;;
  opencode-go|opencodego|opencode_go)
    PROVIDER_ID="opencode-go"
    ;;
esac

# `show --json` only reads the on-disk cache; it never fetches live data.
# Only the plain `show` command actually hits the provider APIs and refreshes
# the cache, so we trigger it ourselves before reading the JSON. On a click we
# block so the user sees fresh data immediately; on the periodic tick we
# refresh in the background so sketchybar isn't held up (the tool's own
# minIntervalMs TTL prevents excessive API calls).
if [ -n "$PROVIDER_ID" ]; then
  if [ "$REFRESHING" -eq 1 ]; then
    "$QUOTA_BIN" show --provider "$PROVIDER_ID" >/dev/null 2>&1
  else
    "$QUOTA_BIN" show --provider "$PROVIDER_ID" >/dev/null 2>&1 &
  fi
fi

if [ -n "$PROVIDER_ID" ]; then
  JSON="$($QUOTA_BIN show --json --provider "$PROVIDER_ID" 2>/dev/null)"
else
  JSON="$($QUOTA_BIN show --json 2>/dev/null)"
fi

if [ -z "$JSON" ]; then
  set_fallback
  exit 0
fi

CACHE_AGE_SECONDS="$(printf '%s' "$JSON" | "$JQ_BIN" -r '.cacheAgeSeconds // 0' 2>/dev/null)"
case "$CACHE_AGE_SECONDS" in
  ''|*[!0-9]*) CACHE_AGE_SECONDS=0 ;;
esac

case "$MODE" in
  openai)
    OPENAI_5H_RAW="$(printf '%s' "$JSON" | "$JQ_BIN" -r '((.providers.openai.entries // []) | map(select((.window // "") == "5h" and .percentRemaining != null)) | .[0].percentRemaining) // empty')"
    OPENAI_7D_RAW="$(printf '%s' "$JSON" | "$JQ_BIN" -r '((.providers.openai.entries // []) | map(select(((.window // "") | ascii_downcase | test("week")) and .percentRemaining != null)) | .[0].percentRemaining) // empty')"
    OPENAI_5H_RESET_RAW="$(printf '%s' "$JSON" | "$JQ_BIN" -r '((.providers.openai.entries // []) | map(select((.window // "") == "5h" and .resetAt != null)) | .[0].resetAt) // empty')"
    OPENAI_7D_RESET_RAW="$(printf '%s' "$JSON" | "$JQ_BIN" -r '((.providers.openai.entries // []) | map(select(((.window // "") | ascii_downcase | test("week")) and .resetAt != null)) | .[0].resetAt) // empty')"

    OPENAI_5H="$(fmt_pct "$OPENAI_5H_RAW")"
    OPENAI_7D="$(fmt_pct "$OPENAI_7D_RAW")"
    OPENAI_5H_RESET="$(fmt_reset_remaining "$OPENAI_5H_RESET_RAW")"
    OPENAI_7D_RESET="$(fmt_reset_remaining "$OPENAI_7D_RESET_RAW")"

    if [ "$OPENAI_5H" = "--" ] && [ "$OPENAI_7D" = "--" ]; then
      restore_sibling_weekly openai_quota_weekly
      set_fallback
      exit 0
    fi

    if [ "$WINDOW" = "weekly" ]; then
      OPENAI_MAIN_VALUE="$OPENAI_7D"
      OPENAI_MAIN_RESET="$OPENAI_7D_RESET"
    else
      OPENAI_MAIN_VALUE="$OPENAI_5H"
      OPENAI_MAIN_RESET="$OPENAI_5H_RESET"
      if [ "$OPENAI_MAIN_VALUE" = "--" ]; then
        OPENAI_MAIN_VALUE="$OPENAI_7D"
        OPENAI_MAIN_RESET="$OPENAI_7D_RESET"
      fi
    fi

    COLOR="$(pick_color_by_pct "$OPENAI_MAIN_VALUE")"

    if [ "$OPENAI_MAIN_VALUE" = "--" ]; then
      OPENAI_MAIN_LABEL="--"
    else
      OPENAI_MAIN_LABEL="${OPENAI_MAIN_VALUE}%"
    fi

    set_item "$WHITE" "$OPENAI_MAIN_LABEL" "$COLOR"

    OPENAI_WEEKLY_LABEL="--"
    OPENAI_WEEKLY_COLOR="$DIM"
    if [ "$OPENAI_7D" != "--" ]; then
      OPENAI_WEEKLY_LABEL="${OPENAI_7D}%"
      OPENAI_WEEKLY_COLOR="$(pick_color_by_pct "$OPENAI_7D")"
    fi

    sketchybar --set openai_quota_weekly label="$OPENAI_WEEKLY_LABEL" label.color="$OPENAI_WEEKLY_COLOR" >/dev/null 2>&1 || true

    apply_openai_split_layout "$OPENAI_5H"

    write_detail_cache "${OPENAI_5H}% (${OPENAI_5H_RESET}) | ${OPENAI_7D}% (${OPENAI_7D_RESET})"
    show_detail_box "${OPENAI_5H}% (${OPENAI_5H_RESET}) | ${OPENAI_7D}% (${OPENAI_7D_RESET})"
    ;;

  copilot)
    COPILOT_RAW="$(printf '%s' "$JSON" | "$JQ_BIN" -r '((.providers.copilot.entries // []) | map(select(.percentRemaining != null)) | .[0].percentRemaining) // empty')"
    COPILOT_RESET_RAW="$(printf '%s' "$JSON" | "$JQ_BIN" -r '((.providers.copilot.entries // []) | map(select(.resetAt != null)) | .[0].resetAt) // empty')"
    COPILOT_PCT="$(fmt_pct "$COPILOT_RAW")"
    COPILOT_RESET="$(fmt_reset_remaining "$COPILOT_RESET_RAW")"

    if [ "$COPILOT_PCT" = "--" ]; then
      set_fallback
      exit 0
    fi

    COLOR="$(pick_color_by_pct "$COPILOT_PCT")"
    set_item "$COPILOT_BLUE" "${COPILOT_PCT}%" "$COLOR"
    write_detail_cache "${COPILOT_PCT}% (${COPILOT_RESET})"
    show_detail_box "${COPILOT_PCT}% (${COPILOT_RESET})"
    ;;

  opencode-go|opencodego|opencode_go)
    OC_5H_RAW="$(printf '%s' "$JSON" | "$JQ_BIN" -r '((.providers["opencode-go"].entries // []) | map(select((.window // "") == "5h" and .percentRemaining != null)) | .[0].percentRemaining) // empty')"
    OC_5H_RESET_RAW="$(printf '%s' "$JSON" | "$JQ_BIN" -r '((.providers["opencode-go"].entries // []) | map(select((.window // "") == "5h" and .resetAt != null)) | .[0].resetAt) // empty')"
    OC_WEEKLY_RAW="$(printf '%s' "$JSON" | "$JQ_BIN" -r '((.providers["opencode-go"].entries // []) | map(select(((.window // "") | ascii_downcase | test("week")) and .percentRemaining != null)) | .[0].percentRemaining) // empty')"
    OC_WEEKLY_RESET_RAW="$(printf '%s' "$JSON" | "$JQ_BIN" -r '((.providers["opencode-go"].entries // []) | map(select(((.window // "") | ascii_downcase | test("week")) and .resetAt != null)) | .[0].resetAt) // empty')"
    OC_MONTHLY_RAW="$(printf '%s' "$JSON" | "$JQ_BIN" -r '((.providers["opencode-go"].entries // []) | map(select(((.window // "") | ascii_downcase | test("month")) and .percentRemaining != null)) | .[0].percentRemaining) // empty')"
    OC_MONTHLY_RESET_RAW="$(printf '%s' "$JSON" | "$JQ_BIN" -r '((.providers["opencode-go"].entries // []) | map(select(((.window // "") | ascii_downcase | test("month")) and .resetAt != null)) | .[0].resetAt) // empty')"

    OC_5H="$(fmt_pct "$OC_5H_RAW")"
    OC_5H_RESET="$(fmt_reset_remaining "$OC_5H_RESET_RAW")"
    OC_WEEKLY="$(fmt_pct "$OC_WEEKLY_RAW")"
    OC_WEEKLY_RESET="$(fmt_reset_remaining "$OC_WEEKLY_RESET_RAW")"
    OC_MONTHLY="$(fmt_pct "$OC_MONTHLY_RAW")"
    OC_MONTHLY_RESET="$(fmt_reset_remaining "$OC_MONTHLY_RESET_RAW")"

    if [ "$OC_5H" = "--" ] && [ "$OC_WEEKLY" = "--" ]; then
      restore_sibling_weekly opencode_quota_weekly
      if ! show_cached_detail_box; then
        show_unavailable_detail "unavailable (provider not detected)"
      fi
      set_fallback
      exit 0
    fi

    if [ "$WINDOW" = "weekly" ]; then
      OC_MAIN_VALUE="$OC_WEEKLY"
      OC_MAIN_RESET="$OC_WEEKLY_RESET"
    else
      OC_MAIN_VALUE="$OC_5H"
      OC_MAIN_RESET="$OC_5H_RESET"
      if [ "$OC_MAIN_VALUE" = "--" ]; then
        OC_MAIN_VALUE="$OC_WEEKLY"
        OC_MAIN_RESET="$OC_WEEKLY_RESET"
      fi
    fi

    COLOR="$(pick_color_by_pct "$OC_MAIN_VALUE")"

    if [ "$OC_MAIN_VALUE" = "--" ]; then
      OC_MAIN_LABEL="--"
    else
      OC_MAIN_LABEL="${OC_MAIN_VALUE}%"
    fi

    set_item "$OC_GO_ICON" "$OC_MAIN_LABEL" "$COLOR"

    OC_WEEKLY_LABEL="--"
    OC_WEEKLY_COLOR="$DIM"
    if [ "$OC_WEEKLY" != "--" ]; then
      OC_WEEKLY_LABEL="${OC_WEEKLY}%"
      OC_WEEKLY_COLOR="$(pick_color_by_pct "$OC_WEEKLY")"
    fi

    sketchybar --set opencode_quota_weekly label="$OC_WEEKLY_LABEL" label.color="$OC_WEEKLY_COLOR" >/dev/null 2>&1 || true

    write_detail_cache "${OC_5H}% (${OC_5H_RESET}) | ${OC_WEEKLY}% (${OC_WEEKLY_RESET}) | ${OC_MONTHLY}% (${OC_MONTHLY_RESET})"
    show_detail_box "${OC_5H}% (${OC_5H_RESET}) | ${OC_WEEKLY}% (${OC_WEEKLY_RESET}) | ${OC_MONTHLY}% (${OC_MONTHLY_RESET})"
    ;;

  *)
    set_fallback
    ;;
esac
