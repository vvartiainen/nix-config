{
  lib,
  pkgs,
  config,
  ...
}:
let
  jsonFormat = pkgs.formats.json { };
  jq = lib.getExe pkgs.jq;

  # Cursor CLI self-repairs and persists some keys into cli-config.json, so
  # this file has to stay writable. Nix settings are merged on activation.
  settings = {
    version = 1;
    attribution = {
      attributeCommitsToAgent = false;
      attributePRsToAgent = false;
      notifications = true;
    };
  };

  staticSettings = jsonFormat.generate "cursor-cli-config.json" settings;
in
{
  home.packages = [
    pkgs.cursor-cli
    (pkgs.runCommand "cursor-cli-agent" { } ''
      mkdir -p $out/bin
      ln -s ${lib.getExe pkgs.cursor-cli} $out/bin/agent
    '')
  ];

  home.activation.cursorCliConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    config_path="${config.home.homeDirectory}/.cursor/cli-config.json"
    mkdir -p "$(dirname "$config_path")"
    if [ -L "$config_path" ]; then
      rm -f "$config_path"
    fi
    if [ ! -e "$config_path" ]; then
      echo '{}' > "$config_path"
    fi
    if ! ${jq} -S '. * $static[0]' \
      --slurpfile static ${staticSettings} \
      "$config_path" > "$config_path.tmp" 2>/dev/null; then
      ${jq} -S '.' ${staticSettings} > "$config_path.tmp"
    fi
    mv "$config_path.tmp" "$config_path"
  '';
}
