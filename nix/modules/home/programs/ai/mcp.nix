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
  # One server per agent backlog, started by each agent CLI on demand.
  backlogServers = lib.listToAttrs (
    map (
      name:
      lib.nameValuePair "backlog-${name}" {
        command = lib.getExe config.backlog.package;
        args = [
          "mcp"
          "start"
          "--cwd"
          "${config.backlog.vault}/${name}"
        ];
      }
    ) config.backlog.projects
  );
  # Stdio MCP servers for every agent CLI.
  servers = {
    nixos = {
      command = lib.getExe pkgs.mcp-nixos;
      args = [ ];
    };
  }
  // backlogServers;
  piSettings = jsonFormat.generate "pi-mcp.json" {
    mcpServers = servers;
  };
  cursorSettings = jsonFormat.generate "cursor-mcp.json" {
    mcpServers = lib.mapAttrs (_: s: s // { type = "stdio"; }) servers;
  };
  claudeCodeSettings = jsonFormat.generate "claude-code-mcp.json" {
    mcpServers = lib.mapAttrs (_: s: s // { type = "stdio"; }) servers;
  };
  copilotSettings = jsonFormat.generate "copilot-mcp.json" {
    mcpServers = lib.mapAttrs (
      _: s:
      s
      // {
        type = "local";
        tools = [ "*" ];
      }
    ) servers;
  };
  opencodeSettings = jsonFormat.generate "opencode-mcp.json" {
    mcp = lib.mapAttrs (_: s: {
      type = "local";
      command = [ s.command ] ++ s.args;
      enabled = true;
    }) servers;
  };
  codexSettings = tomlFormat.generate "codex-mcp.toml" {
    mcp_servers = lib.mapAttrs (_: s: s // { enabled = true; }) servers;
  };
in
{
  home.packages = [ pkgs.mcp-nixos ];

  home.activation.mcpConfig =
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
