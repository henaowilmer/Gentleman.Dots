#!/bin/bash

# Gentleman theme colors (ANSI 256)
PRIMARY='\033[38;5;110m'
ACCENT='\033[38;5;179m'
SECONDARY='\033[38;5;146m'
MUTED='\033[38;5;242m'
SUCCESS='\033[38;5;150m'
ERROR='\033[38;5;174m'
PURPLE='\033[38;5;183m'
BOLD='\033[1m'
NC='\033[0m'

MCP_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude"
MCP_CACHE_FILE="$MCP_CACHE_DIR/statusline-mcp"
MCP_CACHE_TTL=120

input=$(cat)

write_rate_limits_cache() {
  local cache_dir cache_file temp_file captured_at projected

  cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar"
  cache_file="$cache_dir/claude-rate-limits.json"
  captured_at="${CLAUDE_STATUSLINE_NOW:-$(date +%s)}"

  case "$captured_at" in
    ''|*[!0-9]*) return ;;
  esac
  [ "$captured_at" -gt 0 ] && [ "$captured_at" -le 32503680000 ] || return

  projected=$(printf '%s' "$input" | jq -c --argjson captured_at "$captured_at" '
    def valid_percentage:
      type == "number" and isfinite and . >= 0 and . <= 100;
    def valid_epoch:
      type == "number" and isfinite and . > 0 and . <= 32503680000;
    def window($value):
      if ($value | type) == "object"
         and ($value.used_percentage | valid_percentage)
         and ($value.resets_at | valid_epoch)
      then {
        used_percentage: $value.used_percentage,
        resets_at: ($value.resets_at | floor)
      }
      else null
      end;
    (window(.rate_limits.five_hour)) as $five_hour
    | (window(.rate_limits.seven_day)) as $seven_day
    | {captured_at: $captured_at}
      + (if $five_hour == null then {} else {five_hour: $five_hour} end)
      + (if $seven_day == null then {} else {seven_day: $seven_day} end)
    | select(has("five_hour") or has("seven_day"))
  ' 2>/dev/null) || return

  [ -n "$projected" ] || return
  (umask 077 && mkdir -p "$cache_dir") 2>/dev/null || return
  temp_file=$(mktemp "$cache_file.XXXXXX") || return
  chmod 600 "$temp_file" 2>/dev/null || {
    rm -f "$temp_file"
    return
  }
  if ! printf '%s\n' "$projected" > "$temp_file"; then
    rm -f "$temp_file"
    return
  fi
  mv -f "$temp_file" "$cache_file"
}

write_rate_limits_cache

MODEL=$(printf '%s' "$input" | jq -r '.model.display_name // "Claude"')
DIR=$(printf '%s' "$input" | jq -r '.workspace.current_dir // "~"')
ADDED=$(printf '%s' "$input" | jq -r '.cost.total_lines_added // 0')
REMOVED=$(printf '%s' "$input" | jq -r '.cost.total_lines_removed // 0')

CTX_SIZE=$(printf '%s' "$input" | jq -r '.context_window.context_window_size // 200000')
INPUT_TOKENS=$(printf '%s' "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
CACHE_CREATE=$(printf '%s' "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
CACHE_READ=$(printf '%s' "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')

TOTAL_USED=$((INPUT_TOKENS + CACHE_CREATE + CACHE_READ))
if [ "$CTX_SIZE" -gt 0 ] 2>/dev/null; then
  CTX_PERCENT=$((TOTAL_USED * 100 / CTX_SIZE))
else
  CTX_PERCENT=0
fi
[ "$CTX_PERCENT" -gt 100 ] && CTX_PERCENT=100
[ "$CTX_PERCENT" -lt 0 ] && CTX_PERCENT=0

get_mcp_servers() {
  local cache_mtime cache_temp current_dir servers

  if [ -d "$MCP_CACHE_DIR" ] && [ -O "$MCP_CACHE_DIR" ] && [ ! -L "$MCP_CACHE_DIR" ] &&
     [ -f "$MCP_CACHE_FILE" ] && [ -O "$MCP_CACHE_FILE" ] && [ ! -L "$MCP_CACHE_FILE" ]; then
    cache_mtime=$(stat -c %Y "$MCP_CACHE_FILE" 2>/dev/null || stat -f %m "$MCP_CACHE_FILE" 2>/dev/null || printf '0')
    CACHE_AGE=$(($(date +%s) - cache_mtime))
    if [ "$CACHE_AGE" -lt "$MCP_CACHE_TTL" ]; then
      cat "$MCP_CACHE_FILE"
      return
    fi
  fi

  current_dir=$(printf '%s' "$input" | jq -r '.workspace.current_dir // ""')
  servers=""

  if [ -n "$current_dir" ]; then
    servers=$(jq -r --arg dir "$current_dir" '.projects[$dir].mcpServers // {} | keys[]' "$HOME/.claude.json" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
  fi

  if { [ ! -e "$MCP_CACHE_DIR" ] && [ ! -L "$MCP_CACHE_DIR" ]; } ||
     { [ -d "$MCP_CACHE_DIR" ] && [ -O "$MCP_CACHE_DIR" ] && [ ! -L "$MCP_CACHE_DIR" ]; }; then
    (umask 077 && mkdir -p "$MCP_CACHE_DIR") 2>/dev/null || true
    if [ -d "$MCP_CACHE_DIR" ] && [ -O "$MCP_CACHE_DIR" ] && [ ! -L "$MCP_CACHE_DIR" ]; then
      chmod 700 "$MCP_CACHE_DIR" 2>/dev/null || true
      cache_temp=$(mktemp "$MCP_CACHE_DIR/statusline-mcp.XXXXXX" 2>/dev/null || true)
      if [ -n "$cache_temp" ]; then
        if chmod 600 "$cache_temp" 2>/dev/null && printf '%s|\n' "$servers" > "$cache_temp"; then
          mv -f "$cache_temp" "$MCP_CACHE_FILE" 2>/dev/null || rm -f "$cache_temp"
        else
          rm -f "$cache_temp"
        fi
      fi
    fi
  fi
  printf '%s|\n' "$servers"
}

MCP_DATA=$(get_mcp_servers)
MCP_CONNECTED=$(printf '%s' "$MCP_DATA" | cut -d'|' -f1)

DIR_NAME=$(basename "$DIR")
BRANCH=""
GIT_DIRTY=""
if git rev-parse --git-dir >/dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null)
  if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
    GIT_DIRTY="*"
  fi
fi

MODEL_ICON="🤖"
case "$MODEL" in
  *Opus*) MODEL_ICON="🎭" ;;
  *Sonnet*) MODEL_ICON="📝" ;;
  *Haiku*) MODEL_ICON="🍃" ;;
esac

BAR_WIDTH=8
FILLED=$((CTX_PERCENT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))

if [ "$CTX_PERCENT" -ge 80 ]; then
  BAR_COLOR="$ERROR"
elif [ "$CTX_PERCENT" -ge 50 ]; then
  BAR_COLOR="$ACCENT"
else
  BAR_COLOR="$SUCCESS"
fi

BAR="${BAR_COLOR}["
for ((i=0; i<FILLED; i++)); do BAR+="="; done
for ((i=0; i<EMPTY; i++)); do BAR+="."; done
BAR+="]${NC}"

SEP="${MUTED}  ${NC}"
LINE="${BOLD}${PURPLE}${MODEL_ICON} ${MODEL}${NC}"
LINE+="${SEP}${ACCENT}󰉋 ${DIR_NAME}${NC}"

if [ -n "$BRANCH" ]; then
  LINE+="${SEP}${SECONDARY} ${BRANCH}${GIT_DIRTY}${NC}"
fi

LINE+="${SEP}${SUCCESS}+${ADDED}${NC} ${ERROR}-${REMOVED}${NC}"
LINE+="${SEP}${MUTED}ctx${NC} ${BAR} ${MUTED}${CTX_PERCENT}%${NC}"

echo -e "${LINE}\033[K"
