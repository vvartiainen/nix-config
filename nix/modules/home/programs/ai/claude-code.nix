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
  staticSettings = jsonFormat.generate "claude-code-settings.json" {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    model = "opus";
    effortLevel = "medium";
    attribution = {
      commit = "";
      pr = "";
    };
    permissions = permissions.claude;
    sandbox = {
      enabled = true;
      autoAllowBashIfSandboxed = false;
      network.allowedDomains = permissions.urlDomains;
    };
  };
in
{
  programs.claude-code.enable = true;

  # Claude Code persists /config changes here, so merge defaults into a
  # regular file instead of using the Home Manager settings symlink.
  home.activation.claudeCodeConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    config_path="${config.programs.claude-code.configDir}/settings.json"
    mkdir -p "$(dirname "$config_path")"
    if [ ! -e "$config_path" ]; then
      echo '{}' > "$config_path"
    fi
    config_tmp=$(mktemp "$config_path.XXXXXX")
    if ! ${jq} -e -S 'if type == "object" then . * $static[0] else error("expected an object") end' \
      --slurpfile static ${staticSettings} \
      "$config_path" > "$config_tmp"; then
      rm -f "$config_tmp"
      echo >&2 "Could not merge Claude Code settings: $config_path"
      exit 1
    fi
    mv "$config_tmp" "$config_path"
  '';
}
