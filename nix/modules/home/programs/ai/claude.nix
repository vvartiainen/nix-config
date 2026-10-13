{
  lib,
  pkgs,
  config,
  ...
}:
let
  jsonFormat = pkgs.formats.json { };
  jq = lib.getExe pkgs.jq;
  staticSettings = jsonFormat.generate "claude-desktop-config.json" {
    mcpServers.nixos.command = lib.getExe pkgs.mcp-nixos;
  };
in
{
  # The desktop app is installed by the Darwin Homebrew module. Keep its
  # config writable so extensions and manually added MCP servers persist.
  home.activation.claudeDesktopConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    config_path="${config.home.homeDirectory}/Library/Application Support/Claude/claude_desktop_config.json"
    mkdir -p "$(dirname "$config_path")"
    if [ ! -e "$config_path" ]; then
      echo '{}' > "$config_path"
    fi
    config_tmp=$(mktemp "$config_path.XXXXXX")
    if ! ${jq} -e -S 'if type == "object" then . * $static[0] else error("expected an object") end' \
      --slurpfile static ${staticSettings} \
      "$config_path" > "$config_tmp"; then
      rm -f "$config_tmp"
      echo >&2 "Could not merge Claude desktop config: $config_path"
      exit 1
    fi
    mv "$config_tmp" "$config_path"
  '';
}
