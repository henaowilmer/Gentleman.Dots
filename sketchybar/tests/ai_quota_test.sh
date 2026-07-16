#!/bin/bash

set -eu

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PLUGIN="$ROOT/sketchybar/plugins/ai_quota.sh"
STATUSLINE="$ROOT/claude/statusline.sh"
CONFIG="$ROOT/sketchybar/sketchybarrc"
TEST_DIR="$(mktemp -d)"
BIN_DIR="$TEST_DIR/bin"
LOG_FILE="$TEST_DIR/sketchybar.log"
NETWORK_LOG="$TEST_DIR/network.log"
NOW=2000000000

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  grep -Fq -- "$2" "$1" || fail "$3"
}

assert_not_contains() {
  if grep -Fq -- "$2" "$1"; then
    fail "$3"
  fi
}

mkdir -p "$BIN_DIR" "$TEST_DIR/home" "$TEST_DIR/cache"

cat > "$BIN_DIR/sketchybar" <<'EOF'
#!/bin/bash
if [ "${1:-}" = "--query" ]; then
  printf '%s\n' '{"label":{"value":"--","color":"0xffdbe9ff"},"icon":{"value":"x","color":"0xffff9f1c","font":"test"},"geometry":{"background":{"border_color":"0xffff9f1c"}}}'
  exit 0
fi
printf '%s\n' "$*" >> "$LOG_FILE"
EOF

for command in curl security opencode-quota; do
  cat > "$BIN_DIR/$command" <<'EOF'
#!/bin/bash
printf '%s %s\n' "$(basename "$0")" "$*" >> "$NETWORK_LOG"
exit 99
EOF
done

chmod +x "$BIN_DIR"/*
[ -x "$STATUSLINE" ] || fail "status line source must be executable"
[ -x "$PLUGIN" ] || fail "quota plugin source must be executable"

export PATH="$BIN_DIR:$PATH"
export HOME="$TEST_DIR/home"
export XDG_CACHE_HOME="$TEST_DIR/cache"
export OPENCODE_QUOTA_BIN="$BIN_DIR/opencode-quota"
export LOG_FILE NETWORK_LOG
export NAME=claude_quota
export AI_QUOTA_NOW="$NOW"

status_input=$(cat <<EOF
{
  "model":{"display_name":"Claude Test"},
  "workspace":{"current_dir":"$TEST_DIR"},
  "cost":{"total_lines_added":1,"total_lines_removed":2},
  "context_window":{"context_window_size":100,"current_usage":{"input_tokens":10}},
  "account":{"secret":"must-not-persist"},
  "rate_limits":{
    "five_hour":{"used_percentage":25,"resets_at":$((NOW + 3600))},
    "seven_day":{"used_percentage":40,"resets_at":$((NOW + 86400))}
  }
}
EOF
)

CLAUDE_STATUSLINE_NOW="$NOW" "$STATUSLINE" <<< "$status_input" >/dev/null
RATE_FILE="$XDG_CACHE_HOME/sketchybar/claude-rate-limits.json"
MCP_FILE="$XDG_CACHE_HOME/claude/statusline-mcp"
[ -f "$RATE_FILE" ] || fail "status line must create the rate-limit sidecar"
[ "$(stat -c '%a' "$RATE_FILE" 2>/dev/null || stat -f '%Lp' "$RATE_FILE")" = "600" ] || fail "sidecar mode must be 0600"
[ -f "$MCP_FILE" ] || fail "status line must create the MCP cache under XDG cache"
[ "$(stat -c '%a' "$MCP_FILE" 2>/dev/null || stat -f '%Lp' "$MCP_FILE")" = "600" ] || fail "MCP cache mode must be 0600"
[ "$(stat -c '%a' "$XDG_CACHE_HOME/claude" 2>/dev/null || stat -f '%Lp' "$XDG_CACHE_HOME/claude")" = "700" ] || fail "MCP cache directory mode must be 0700"
assert_not_contains "$STATUSLINE" '/tmp/claude_mcp_cache' "status line must not reference the shared legacy MCP cache"
jq -e 'keys == ["captured_at","five_hour","seven_day"] and .five_hour.used_percentage == 25 and .seven_day.used_percentage == 40' "$RATE_FILE" >/dev/null || fail "sidecar must contain only projected rate limits"
assert_not_contains "$RATE_FILE" 'secret' "sidecar must never persist account or session data"

partial_input=$(printf '%s' "$status_input" | jq '.rate_limits.five_hour.used_percentage = 101')
CLAUDE_STATUSLINE_NOW="$((NOW + 1))" "$STATUSLINE" <<< "$partial_input" >/dev/null
jq -e 'has("five_hour") | not' "$RATE_FILE" >/dev/null || fail "invalid 5h data must be omitted independently"
jq -e 'has("seven_day")' "$RATE_FILE" >/dev/null || fail "valid 7d data must survive an invalid 5h window"
invalid_input=$(printf '%s' "$partial_input" | jq 'del(.rate_limits.seven_day)')
CLAUDE_STATUSLINE_NOW="$((NOW + 2))" "$STATUSLINE" <<< "$invalid_input" >/dev/null
jq -e '.captured_at == ($now + 1)' --argjson now "$NOW" "$RATE_FILE" >/dev/null || fail "fully invalid input must not replace the last usable cache"
CLAUDE_STATUSLINE_NOW="$NOW" "$STATUSLINE" <<< "$status_input" >/dev/null

: > "$LOG_FILE"
: > "$NETWORK_LOG"
"$PLUGIN" claude
assert_contains "$LOG_FILE" '--set claude_quota icon.color=0xffff9f1c label=75%' "fresh 5h data must use the sidecar"
assert_contains "$LOG_FILE" '--set claude_quota_weekly icon.color=0xffff9f1c label=60%' "fresh 7d data must be updated independently"
[ ! -s "$NETWORK_LOG" ] || fail "Claude periodic mode must not invoke network-capable commands"

: > "$LOG_FILE"
"$PLUGIN" claude click
assert_contains "$LOG_FILE" 'label=75% (1h 0m) | 60% (1d 0h) label.color=' "click detail must use the exact compact format"
assert_not_contains "$LOG_FILE" 'status-line' "click detail must not expose the local source"
assert_not_contains "$LOG_FILE" 'waiting for the next Claude response' "click detail must not include refresh guidance when values exist"
[ ! -s "$NETWORK_LOG" ] || fail "Claude click mode must remain local-only"

jq --argjson captured_at "$((NOW - 900))" '.captured_at = $captured_at' "$RATE_FILE" > "$RATE_FILE.tmp"
mv "$RATE_FILE.tmp" "$RATE_FILE"
: > "$LOG_FILE"
"$PLUGIN" claude
assert_contains "$LOG_FILE" 'label=75%~' "15-minute-old data must have a visible stale marker"
assert_contains "$LOG_FILE" 'label=60%~' "each stale window must be marked"

rm -f "$RATE_FILE"
cat > "$HOME/.claude.json" <<EOF
{"cachedUsageUtilization":{"fetchedAtMs":$(((NOW - 1200) * 1000)),"utilization":{"five_hour":{"utilization":30,"resets_at":"2033-05-18T04:33:20Z"},"seven_day":{"utilization":50,"resets_at":"2033-05-19T03:33:20Z"}}}}
EOF
touch "$HOME/.claude.json"
: > "$LOG_FILE"
"$PLUGIN" claude click
assert_contains "$LOG_FILE" 'label=70%~' "fallback freshness must use fetchedAtMs instead of file mtime"
assert_contains "$LOG_FILE" 'label=70% (1h 0m) | 50% (1d 0h) label.color=' "stale click detail must remain compact"
assert_not_contains "$LOG_FILE" 'claude-cache' "stale click detail must not expose the local source"

cat > "$RATE_FILE" <<EOF
{"captured_at":$NOW,"five_hour":{"used_percentage":25,"resets_at":$((NOW + 3600))}}
EOF
cat > "$HOME/.claude.json" <<EOF
{"cachedUsageUtilization":{"fetchedAtMs":$((NOW * 1000)),"utilization":{"seven_day":{"utilization":50,"resets_at":"2033-05-19T03:33:20Z"}}}}
EOF
: > "$LOG_FILE"
"$PLUGIN" claude click
assert_contains "$LOG_FILE" 'label=75%' "5h must select the independently available status-line window"
assert_contains "$LOG_FILE" 'label=50%' "7d must fall back independently to cachedUsageUtilization"
assert_contains "$LOG_FILE" 'label=75% (1h 0m) | 50% (1d 0h) label.color=' "mixed-source detail must remain compact"

cat > "$RATE_FILE" <<EOF
{"captured_at":$((NOW - 3700)),"five_hour":{"used_percentage":20,"resets_at":$((NOW + 300))},"seven_day":{"used_percentage":150,"resets_at":$((NOW + 300))}}
EOF
rm -f "$HOME/.claude.json" "$XDG_CACHE_HOME/sketchybar/ai_quota_claude_weekly.state"
: > "$LOG_FILE"
"$PLUGIN" claude click
assert_contains "$LOG_FILE" 'label=80%!' "over-60-minute data may be retained only as old"
assert_contains "$LOG_FILE" '--set claude_quota_weekly icon.color=0xffff9f1c label=--!' "invalid windows must fail independently"
assert_contains "$LOG_FILE" 'label=80% (5m) | unavailable label.color=' "missing windows must use a concise truthful detail fallback"
[ ! -s "$NETWORK_LOG" ] || fail "all Claude scenarios must avoid network-capable commands"

cat > "$RATE_FILE" <<EOF
{"captured_at":$NOW,"five_hour":{"used_percentage":10,"resets_at":$((NOW - 1))}}
EOF
: > "$LOG_FILE"
"$PLUGIN" claude
assert_contains "$LOG_FILE" 'label=90%!' "a passed reset must never be presented as fresh"

claude_block="$(sed -n '/# CLAUDE QUOTA/,/# OPENAI QUOTA/p' "$CONFIG")"
[ "$(printf '%s\n' "$claude_block" | grep -c 'update_freq=60')" -eq 1 ] || fail "Claude must have one periodic updater"
weekly_block="$(printf '%s\n' "$claude_block" | sed -n '/add item claude_quota_weekly/,$p')"
if printf '%s\n' "$weekly_block" | grep -Eq 'update_freq=|script=.*claude weekly"'; then
  fail "weekly item must not schedule duplicate updates"
fi

printf 'ok - Claude local quota contracts\n'
