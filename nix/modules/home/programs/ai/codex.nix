{
  lib,
  pkgs,
  config,
  ...
}:
let
  permissions = import ./permissions.nix { inherit lib; };
  hooks = import ./hooks.nix { inherit lib pkgs; };
  commandRules = pkgs.writeText "codex-nix-config.rules" permissions.codexRules;
  codexHookPath = "${config.home.homeDirectory}/.codex/hooks/${hooks.codex.hookFileName}";
in
{
  programs.codex = {
    enable = true;
    hooks.PreToolUse = [
      {
        matcher = hooks.codex.matcher;
        hooks = [
          {
            type = "command";
            command = "${codexHookPath} --format codex";
            timeout = hooks.codex.timeout;
            statusMessage = "Checking nix-darwin apply commands";
          }
        ];
      }
    ];
  };

  home.file.".codex/hooks/${hooks.codex.hookFileName}".source = lib.getExe hooks.script;

  # Codex writes project trust, MCP changes, and other runtime settings to
  # config.toml. Keep both it and the rules directory outside the Nix store.
  home.activation.codexMutableConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    config_dir="${config.home.homeDirectory}/.codex"
    config_path="$config_dir/config.toml"
    rules_path="$config_dir/rules/nix-config.rules"

    mkdir -p "$config_dir/rules"
    if [ -L "$config_path" ]; then
      config_tmp="$config_path.tmp"
      cp -L "$config_path" "$config_tmp"
      rm -f "$config_path"
      mv "$config_tmp" "$config_path"
    elif [ ! -e "$config_path" ]; then
      touch "$config_path"
    fi
    chmod u+w "$config_path"

    if [ -L "$rules_path" ]; then
      rm -f "$rules_path"
    fi
    install -m 0644 ${commandRules} "$rules_path"
  '';
}
