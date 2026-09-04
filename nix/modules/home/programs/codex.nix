{
  lib,
  pkgs,
  config,
  ...
}:
let
  commandRules = pkgs.writeText "codex-nix-config.rules" ''
    prefix_rule(pattern = ["git", "status"], decision = "allow")
    prefix_rule(pattern = ["git", "diff"], decision = "allow")
    prefix_rule(pattern = ["grep"], decision = "allow")
    prefix_rule(pattern = ["npm", "run", "test"], decision = "allow")
    prefix_rule(pattern = ["npm", "run", "build"], decision = "allow")
    prefix_rule(pattern = ["npm", "run", "format"], decision = "allow")
    prefix_rule(pattern = ["npm", "test"], decision = "allow")
    prefix_rule(pattern = ["npx", "vitest"], decision = "allow")
    prefix_rule(pattern = ["npx", "tsc"], decision = "allow")
    prefix_rule(pattern = ["npx", "eslint"], decision = "allow")
    prefix_rule(pattern = ["terraform", "fmt"], decision = "allow")
    prefix_rule(pattern = ["terraform", "validate"], decision = "allow")
  '';
in
{
  programs.codex = {
    enable = true;
  };

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
