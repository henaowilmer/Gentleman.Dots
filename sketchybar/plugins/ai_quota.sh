#!/bin/bash

# AI quota - provider-specific quota labels from opencode-quota cache

GREEN=0xff4dff88
YELLOW=0xffffd23d
RED=0xffff3d81
DIM=0xff4a5578
WHITE=0xffdbe9ff
ORANGE=0xffff9f1c
COPILOT_BLUE=0xff347aff

export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:$HOME/.local/state/nix/profiles/home-manager/home-path/bin:$HOME/.nix-profile/bin"

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
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

read_cache() {
  if [ -f "$CACHE_FILE" ]; then
    cat "$CACHE_FILE" 2>/dev/null
  fi
}

write_cache() {
  local color="$1"
  local label="$2"
  mkdir -p "$CACHE_DIR" 2>/dev/null || true
  printf '%s|%s\n' "$color" "$label" > "$CACHE_FILE" 2>/dev/null || true
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
  mkdir -p "$CACHE_DIR" 2>/dev/null || true
  printf '%s\n' "$detail" > "$DETAIL_CACHE_FILE" 2>/dev/null || true
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
    if [ "$MODE" = "openai" ] || [ "$MODE" = "claude" ] || [ "$MODE" = "anthropic" ]; then
      case "$cached_label" in
        *" | "*) cached_label="" ;;
      esac
    fi
    if [ "$WINDOW" = "weekly" ] && { [ "$MODE" = "openai" ] || [ "$MODE" = "claude" ] || [ "$MODE" = "anthropic" ]; }; then
      cached_label="${cached_label#| }"
      cached_label="${cached_label#|}"
    fi
    if [ -n "$cached_color" ] && [ -n "$cached_label" ] && [ "$cached_label" != "$cached" ]; then
      fallback_label_color="${current_label_color:-$WHITE}"
      if [ "$MODE" = "openai" ] || [ "$MODE" = "claude" ] || [ "$MODE" = "anthropic" ]; then
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
    if [ "$MODE" = "openai" ] || [ "$MODE" = "claude" ] || [ "$MODE" = "anthropic" ]; then
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
      if [ "$MODE" = "openai" ] || [ "$MODE" = "claude" ] || [ "$MODE" = "anthropic" ]; then
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

  now="$(date +%s)"
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

extract_access_token_from_json() {
  local raw="$1"
  printf '%s' "$raw" | "$JQ_BIN" -r '.claudeAiOauth.accessToken // .oauth.accessToken // .accessToken // .access_token // .token // empty' 2>/dev/null
}

get_claude_oauth_json() {
  local token_raw=""
  local token=""
  local response=""

  if [ "$(uname -s)" = "Darwin" ]; then
    token_raw="$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null || true)"
    if [ -n "$token_raw" ]; then
      if printf '%s' "$token_raw" | grep -q '^[[:space:]]*[{\[]'; then
        token="$(extract_access_token_from_json "$token_raw")"
      else
        token="$token_raw"
      fi
    fi
  fi

  if [ -z "$token" ] && [ -f "$HOME/.claude/.credentials.json" ]; then
    token="$("$JQ_BIN" -r '.claudeAiOauth.accessToken // .oauth.accessToken // .accessToken // .access_token // .token // empty' "$HOME/.claude/.credentials.json" 2>/dev/null)"
  fi

  if [ -z "$token" ]; then
    return 1
  fi

  response="$(curl -fsS --max-time 6 \
    --retry 1 \
    --retry-delay 1 \
    --retry-all-errors \
    --retry-max-time 10 \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" \
    "https://api.anthropic.com/api/oauth/usage" 2>/dev/null || true)"

  if [ -z "$response" ]; then
    return 1
  fi

  if ! printf '%s' "$response" | "$JQ_BIN" -e . >/dev/null 2>&1; then
    return 1
  fi

  printf '%s' "$response"
}

if [ ! -x "$QUOTA_BIN" ]; then
  QUOTA_BIN="$(command -v opencode-quota 2>/dev/null || true)"
fi

if [ -z "$QUOTA_BIN" ]; then
  set_fallback
  exit 0
fi

if [ -z "$JQ_BIN" ]; then
  set_fallback
  exit 0
fi

show_refresh_feedback

PROVIDER_ID=""
case "$MODE" in
  openai)
    PROVIDER_ID="openai"
    ;;
  anthropic|claude)
    PROVIDER_ID="anthropic"
    ;;
  copilot)
    PROVIDER_ID="copilot"
    ;;
esac

if [ -n "$PROVIDER_ID" ]; then
  JSON="$($QUOTA_BIN show --json --provider "$PROVIDER_ID" 2>/dev/null)"
else
  JSON="$($QUOTA_BIN show --json 2>/dev/null)"
fi

if [ -z "$JSON" ]; then
  set_fallback
  exit 0
fi

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
      sketchybar --set openai_quota_weekly label="--" label.color="$DIM" >/dev/null 2>&1 || true
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

    write_detail_cache "${OPENAI_5H}% (${OPENAI_5H_RESET}) | ${OPENAI_7D}% (${OPENAI_7D_RESET})"
    show_detail_box "${OPENAI_5H}% (${OPENAI_5H_RESET}) | ${OPENAI_7D}% (${OPENAI_7D_RESET})"
    ;;

  anthropic|claude)
    CLAUDE_5H_RAW="$(printf '%s' "$JSON" | "$JQ_BIN" -r '((.providers.anthropic.entries // []) | map(select((.window // "") == "5h" and .percentRemaining != null)) | .[0].percentRemaining) // empty')"
    CLAUDE_5H_RESET_RAW="$(printf '%s' "$JSON" | "$JQ_BIN" -r '((.providers.anthropic.entries // []) | map(select((.window // "") == "5h" and .resetAt != null)) | .[0].resetAt) // empty')"
    CLAUDE_WEEKLY_RAW="$(printf '%s' "$JSON" | "$JQ_BIN" -r '((.providers.anthropic.entries // []) | map(select(((.window // "") | ascii_downcase | test("week")) and .percentRemaining != null)) | .[0].percentRemaining) // empty')"
    CLAUDE_WEEKLY_RESET_RAW="$(printf '%s' "$JSON" | "$JQ_BIN" -r '((.providers.anthropic.entries // []) | map(select(((.window // "") | ascii_downcase | test("week")) and .resetAt != null)) | .[0].resetAt) // empty')"

    CLAUDE_5H="$(fmt_pct "$CLAUDE_5H_RAW")"
    CLAUDE_5H_RESET="$(fmt_reset_remaining "$CLAUDE_5H_RESET_RAW")"
    CLAUDE_WEEKLY="$(fmt_pct "$CLAUDE_WEEKLY_RAW")"
    CLAUDE_WEEKLY_RESET="$(fmt_reset_remaining "$CLAUDE_WEEKLY_RESET_RAW")"

    if [ "$CLAUDE_5H" = "--" ]; then
      CLAUDE_OAUTH_JSON="$(get_claude_oauth_json || true)"
      if [ -n "$CLAUDE_OAUTH_JSON" ]; then
        CLAUDE_OAUTH_5H_USED="$(printf '%s' "$CLAUDE_OAUTH_JSON" | "$JQ_BIN" -r '
          def fiveh:
            .five_hour // .fiveHour //
            .quota.five_hour // .quota.fiveHour //
            .usage.five_hour // .usage.fiveHour //
            .rate_limits.five_hour // .rate_limits.fiveHour //
            .rateLimits.five_hour // .rateLimits.fiveHour //
            .oauth_usage.five_hour // .oauth_usage.fiveHour //
            .oauthUsage.five_hour // .oauthUsage.fiveHour;
          def used($w):
            [$w.utilization, $w.used_percentage, $w.usedPercentage, $w.used_percent, $w.usedPercent, $w.percent_used, $w.percentUsed]
            | map(select(. != null))
            | .[0];
          fiveh as $w
          | if ($w | type) == "object" then (used($w) // empty) else empty end
        ' 2>/dev/null)"

        CLAUDE_OAUTH_5H_RESET_RAW="$(printf '%s' "$CLAUDE_OAUTH_JSON" | "$JQ_BIN" -r '
          def fiveh:
            .five_hour // .fiveHour //
            .quota.five_hour // .quota.fiveHour //
            .usage.five_hour // .usage.fiveHour //
            .rate_limits.five_hour // .rate_limits.fiveHour //
            .rateLimits.five_hour // .rateLimits.fiveHour //
            .oauth_usage.five_hour // .oauth_usage.fiveHour //
            .oauthUsage.five_hour // .oauthUsage.fiveHour;
          fiveh as $w
          | if ($w | type) == "object" then ($w.resets_at // $w.resetsAt // $w.reset_at // $w.resetAt // $w.reset_time // $w.resetTime // $w.reset // empty) else empty end
        ' 2>/dev/null)"

        CLAUDE_OAUTH_WEEKLY_USED="$(printf '%s' "$CLAUDE_OAUTH_JSON" | "$JQ_BIN" -r '
          def weekly:
            .seven_day // .sevenDay //
            .quota.seven_day // .quota.sevenDay //
            .usage.seven_day // .usage.sevenDay //
            .rate_limits.seven_day // .rate_limits.sevenDay //
            .rateLimits.seven_day // .rateLimits.sevenDay //
            .oauth_usage.seven_day // .oauth_usage.sevenDay //
            .oauthUsage.seven_day // .oauthUsage.sevenDay;
          def used($w):
            [$w.utilization, $w.used_percentage, $w.usedPercentage, $w.used_percent, $w.usedPercent, $w.percent_used, $w.percentUsed]
            | map(select(. != null))
            | .[0];
          weekly as $w
          | if ($w | type) == "object" then (used($w) // empty) else empty end
        ' 2>/dev/null)"

        CLAUDE_OAUTH_WEEKLY_RESET_RAW="$(printf '%s' "$CLAUDE_OAUTH_JSON" | "$JQ_BIN" -r '
          def weekly:
            .seven_day // .sevenDay //
            .quota.seven_day // .quota.sevenDay //
            .usage.seven_day // .usage.sevenDay //
            .rate_limits.seven_day // .rate_limits.sevenDay //
            .rateLimits.seven_day // .rateLimits.sevenDay //
            .oauth_usage.seven_day // .oauth_usage.sevenDay //
            .oauthUsage.seven_day // .oauthUsage.sevenDay;
          weekly as $w
          | if ($w | type) == "object" then ($w.resets_at // $w.resetsAt // $w.reset_at // $w.resetAt // $w.reset_time // $w.resetTime // $w.reset // empty) else empty end
        ' 2>/dev/null)"

        if [ -n "$CLAUDE_OAUTH_5H_USED" ]; then
          CLAUDE_5H_RAW_FROM_OAUTH="$(printf '%s' "$CLAUDE_OAUTH_5H_USED" | awk '{ printf "%d", 100 - $1 }')"
          CLAUDE_5H="$(fmt_pct "$CLAUDE_5H_RAW_FROM_OAUTH")"
          CLAUDE_5H_RESET="$(fmt_reset_remaining "$CLAUDE_OAUTH_5H_RESET_RAW")"
        fi

        if [ -n "$CLAUDE_OAUTH_WEEKLY_USED" ]; then
          CLAUDE_WEEKLY_RAW_FROM_OAUTH="$(printf '%s' "$CLAUDE_OAUTH_WEEKLY_USED" | awk '{ printf "%d", 100 - $1 }')"
          CLAUDE_WEEKLY="$(fmt_pct "$CLAUDE_WEEKLY_RAW_FROM_OAUTH")"
          CLAUDE_WEEKLY_RESET="$(fmt_reset_remaining "$CLAUDE_OAUTH_WEEKLY_RESET_RAW")"
        fi
      fi
    fi

    if [ "$CLAUDE_5H" = "--" ] && [ "$CLAUDE_WEEKLY" = "--" ]; then
      sketchybar --set claude_quota_weekly label="--" label.color="$DIM" >/dev/null 2>&1 || true
      if ! show_cached_detail_box; then
        show_unavailable_detail "unavailable (rate limit/network)"
      fi
      set_fallback
      exit 0
    fi

    if [ "$WINDOW" = "weekly" ]; then
      CLAUDE_MAIN_VALUE="$CLAUDE_WEEKLY"
    else
      CLAUDE_MAIN_VALUE="$CLAUDE_5H"
      if [ "$CLAUDE_MAIN_VALUE" = "--" ]; then
        CLAUDE_MAIN_VALUE="$CLAUDE_WEEKLY"
      fi
    fi

    if [ "$CLAUDE_MAIN_VALUE" != "--" ]; then
      COLOR="$(pick_color_by_pct "$CLAUDE_MAIN_VALUE")"
      CLAUDE_LABEL="${CLAUDE_MAIN_VALUE}%"
    else
      COLOR="$(pick_color_by_pct "$CLAUDE_WEEKLY")"
      CLAUDE_LABEL="${CLAUDE_WEEKLY}%"
    fi

    set_item "$ORANGE" "$CLAUDE_LABEL" "$COLOR"

    CLAUDE_WEEKLY_LABEL="--"
    CLAUDE_WEEKLY_COLOR="$DIM"
    if [ "$CLAUDE_WEEKLY" != "--" ]; then
      CLAUDE_WEEKLY_LABEL="${CLAUDE_WEEKLY}%"
      CLAUDE_WEEKLY_COLOR="$(pick_color_by_pct "$CLAUDE_WEEKLY")"
    fi

    sketchybar --set claude_quota_weekly label="$CLAUDE_WEEKLY_LABEL" label.color="$CLAUDE_WEEKLY_COLOR" >/dev/null 2>&1 || true

    write_detail_cache "${CLAUDE_5H}% (${CLAUDE_5H_RESET}) | ${CLAUDE_WEEKLY}% (${CLAUDE_WEEKLY_RESET})"
    show_detail_box "${CLAUDE_5H}% (${CLAUDE_5H_RESET}) | ${CLAUDE_WEEKLY}% (${CLAUDE_WEEKLY_RESET})"
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

  *)
    set_fallback
    ;;
esac
