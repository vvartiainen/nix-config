{
  lib,
  pkgs,
  config,
  ...
}:
let
  jsonFormat = pkgs.formats.json { };
  jq = lib.getExe pkgs.jq;
  permissions = import ./permissions.nix { inherit lib; };
  cursorConfigDir = "${config.xdg.configHome}/cursor";

  # Cursor CLI self-repairs and persists some keys into cli-config.json, so
  # this file has to stay writable. Nix settings are merged on activation.
  settings = {
    version = 1;
    editor.vimMode = false;
    permissions = {
      inherit (permissions.cursor) allow deny;
    };
    sandbox = {
      mode = "enabled";
      networkAccess = "user_config_with_defaults";
    };
    attribution = {
      attributeCommitsToAgent = false;
      attributePRsToAgent = false;
      notifications = true;
    };
  };

  sandboxSettings = {
    additionalReadonlyPaths = permissions.sandboxReadonlyPaths config.xdg;
  };

  staticSettings = jsonFormat.generate "cursor-cli-config.json" settings;
  staticSandbox = jsonFormat.generate "cursor-sandbox.json" sandboxSettings;
in
{
  home.sessionVariables.CURSOR_CONFIG_DIR = cursorConfigDir;

  home.packages = [
    pkgs.cursor-cli
    (pkgs.runCommand "cursor-cli-agent" { } ''
      mkdir -p $out/bin
      ln -s ${lib.getExe pkgs.cursor-cli} $out/bin/agent
    '')
  ];

  home.activation.cursorCliConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    merge_cursor_config() {
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

    merge_cursor_config \
      "${cursorConfigDir}/cli-config.json" \
      ${staticSettings}
    merge_cursor_config \
      "${cursorConfigDir}/sandbox.json" \
      ${staticSandbox}
  '';
}
