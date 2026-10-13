{
  lib,
  pkgs,
  config,
  ...
}:
let
  jsonFormat = pkgs.formats.json { };
  tomlFormat = pkgs.formats.toml { };
  jq = lib.getExe pkgs.jq;
  yq = lib.getExe pkgs.yq-go;
  mcpNixos = lib.getExe pkgs.mcp-nixos;
  piSettings = jsonFormat.generate "pi-mcp-nixos.json" {
    mcpServers.nixos = {
      command = mcpNixos;
    };
  };
  cursorSettings = jsonFormat.generate "cursor-mcp-nixos.json" {
    mcpServers.nixos = {
      type = "stdio";
      command = mcpNixos;
    };
  };
  claudeCodeSettings = jsonFormat.generate "claude-code-mcp-nixos.json" {
    mcpServers.nixos = {
      type = "stdio";
      command = mcpNixos;
    };
  };
  copilotSettings = jsonFormat.generate "copilot-mcp-nixos.json" {
    mcpServers.nixos = {
      type = "local";
      command = mcpNixos;
      tools = [ "*" ];
    };
  };
  opencodeSettings = jsonFormat.generate "opencode-mcp-nixos.json" {
    mcp.nixos = {
      type = "local";
      command = [ mcpNixos ];
      enabled = true;
    };
  };
  codexSettings = tomlFormat.generate "codex-mcp-nixos.toml" {
    mcp_servers.nixos = {
      command = mcpNixos;
      enabled = true;
    };
  };
in
{
  home.packages = [ pkgs.mcp-nixos ];

  home.activation.mcpNixosConfig =
    lib.hm.dag.entryAfter
      [
        "linkGeneration"
        "codexMutableConfig"
        "githubCopilotCliSettings"
        "opencodeConfig"
        "cursorCliConfig"
        "claudeCodeConfig"
      ]
      ''
        merge_mcp_config() {
          config_path="$1"
          static_path="$2"
          mkdir -p "$(dirname "$config_path")"
          if [ -L "$config_path" ]; then
            rm -f "$config_path"
          fi
          if [ ! -e "$config_path" ]; then
            echo '{}' > "$config_path"
          fi
          if ! ${jq} -S '. * $static[0]' \
            --slurpfile static "$static_path" \
            "$config_path" > "$config_path.tmp" 2>/dev/null; then
            ${jq} -S '.' "$static_path" > "$config_path.tmp"
          fi
          mv "$config_path.tmp" "$config_path"
        }

        merge_mcp_config \
          "${config.home.homeDirectory}/.pi/agent/mcp.json" \
          ${piSettings}
        merge_mcp_config \
          "${config.xdg.configHome}/cursor/mcp.json" \
          ${cursorSettings}
        merge_mcp_config \
          "${config.programs.github-copilot-cli.configDir}/mcp-config.json" \
          ${copilotSettings}
        merge_mcp_config \
          "${config.xdg.configHome}/opencode/opencode.json" \
          ${opencodeSettings}

        # User-scoped MCP servers belong in .claude.json, alongside runtime
        # state. Preserve that state and leave malformed files untouched.
        claude_config="${config.home.homeDirectory}/.claude.json"
        if [ ! -e "$claude_config" ]; then
          echo '{}' > "$claude_config"
        fi
        claude_tmp=$(mktemp "$claude_config.XXXXXX")
        if ! ${jq} -e -S 'if type == "object" then . * $static[0] else error("expected an object") end' \
          --slurpfile static ${claudeCodeSettings} \
          "$claude_config" > "$claude_tmp"; then
          rm -f "$claude_tmp"
          echo >&2 "Could not merge Claude Code MCP config: $claude_config"
          exit 1
        fi
        mv "$claude_tmp" "$claude_config"

        codex_config="${config.home.homeDirectory}/.codex/config.toml"
        if ! ${yq} eval-all \
          --input-format toml \
          --output-format toml \
          '. as $item ireduce ({}; . * $item)' \
          "$codex_config" ${codexSettings} > "$codex_config.tmp" 2>/dev/null; then
          cp ${codexSettings} "$codex_config.tmp"
        fi
        mv "$codex_config.tmp" "$codex_config"
      '';
}
