{ pkgs, lib, ... }:

{
  # Required packages for statusline
  home.packages = [
    pkgs.jq
  ];

  home.file.".claude/statusline.sh" = {
    source = ./claude/statusline.sh;
    executable = true;
  };

  # Merge MCP servers into ~/.claude.json on activation
  home.activation.installClaudeConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    export PATH="${pkgs.coreutils}/bin:${pkgs.jq}/bin:$PATH"

    CLAUDE_JSON="$HOME/.claude.json"
    CLAUDE_SETTINGS="$HOME/.claude/settings.json"
    CLAUDE_TEMP=""
    SETTINGS_TEMP=""

    cleanup_claude_temp() {
      [ -z "$CLAUDE_TEMP" ] || rm -f "$CLAUDE_TEMP"
      [ -z "$SETTINGS_TEMP" ] || rm -f "$SETTINGS_TEMP"
    }
    trap cleanup_claude_temp EXIT HUP INT TERM

    mkdir -p "$HOME/.claude"
    chmod 700 "$HOME/.claude"
    CLAUDE_TEMP="$(mktemp "$HOME/.claude.json.XXXXXX")"
    chmod 600 "$CLAUDE_TEMP"

    if [ -f "$CLAUDE_JSON" ]; then
      ${pkgs.jq}/bin/jq --argjson servers '{
        "context7":{"type":"http","url":"https://mcp.context7.com/mcp"},
        "engram":{"type":"stdio","command":"engram","args":["mcp"]},
        "notion":{"type":"http","url":"https://mcp.notion.com/mcp"}
      }' '.mcpServers = (.mcpServers // {}) + $servers' "$CLAUDE_JSON" > "$CLAUDE_TEMP"
    else
      printf '%s\n' '{"mcpServers":{"context7":{"type":"http","url":"https://mcp.context7.com/mcp"},"engram":{"type":"stdio","command":"engram","args":["mcp"]},"notion":{"type":"http","url":"https://mcp.notion.com/mcp"}}}' > "$CLAUDE_TEMP"
    fi
    mv -f "$CLAUDE_TEMP" "$CLAUDE_JSON"
    CLAUDE_TEMP=""
    chmod 600 "$CLAUDE_JSON"

    SETTINGS_TEMP="$(mktemp "$HOME/.claude/settings.json.XXXXXX")"
    chmod 600 "$SETTINGS_TEMP"
    if [ -f "$CLAUDE_SETTINGS" ]; then
      ${pkgs.jq}/bin/jq --arg command "$HOME/.claude/statusline.sh" \
        '.statusLine = ((.statusLine // {}) + {"type":"command","command":$command})' \
        "$CLAUDE_SETTINGS" > "$SETTINGS_TEMP"
    else
      ${pkgs.jq}/bin/jq -n --arg command "$HOME/.claude/statusline.sh" \
        '{"statusLine":{"type":"command","command":$command}}' > "$SETTINGS_TEMP"
    fi
    mv -f "$SETTINGS_TEMP" "$CLAUDE_SETTINGS"
    SETTINGS_TEMP=""
    chmod 600 "$CLAUDE_SETTINGS"
    trap - EXIT HUP INT TERM
  '';

  programs.fish.shellAliases = {
    cc = "claude";
    claude-config = "nvim ~/.claude/settings.json";
  };

  programs.zsh.shellAliases = {
    cc = "claude";
    claude-config = "nvim ~/.claude/settings.json";
  };
}
