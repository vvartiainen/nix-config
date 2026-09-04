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
  cursorSettings = jsonFormat.generate "cursor-mcp-nixos.json" {
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
        "codexMutableConfig"
        "githubCopilotCliSettings"
        "opencodeConfig"
        "cursorCliConfig"
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
          "${config.home.homeDirectory}/.cursor/mcp.json" \
          ${cursorSettings}
        merge_mcp_config \
          "${config.programs.github-copilot-cli.configDir}/mcp-config.json" \
          ${copilotSettings}
        merge_mcp_config \
          "${config.xdg.configHome}/opencode/opencode.json" \
          ${opencodeSettings}

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
