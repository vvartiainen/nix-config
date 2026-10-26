{
  lib,
  pkgs,
  config,
  ...
}:
let
  mergeConfig = import ../../merge-config.nix { inherit lib pkgs config; };
  permissions = import ./permissions.nix { inherit lib; };
  commandRules = pkgs.writeText "codex-nix-config.rules" permissions.codexRules;
  settings = permissions.codexPermissions config // {
    shell_environment_policy.set = {
      NIX_CACHE_HOME = "${config.home.homeDirectory}/.cache/nix-agent";
      CARGO_HOME = "${config.xdg.cacheHome}/cargo-agent";
    };

    # Codex only supports built-in status line items (no custom command),
    # so mirror claude-statusline.sh as closely as possible.
    tui = {
      theme = "catppuccin-mocha";
      status_line_use_colors = true;
      status_line = [
        "model-with-reasoning"
        "current-dir"
        "git-branch"
        "context-used"
        "five-hour-limit"
        "weekly-limit"
        "estimated-thread-cost"
      ];
      keymap.global = {
        open_transcript = [
          "ctrl-o"
          "ctrl-t"
        ];
        # Ctrl+O inspects output across the agent CLIs.
        copy = "alt-y";
      };
    };
  };
  profile = (permissions.codexPermissions config).default_permissions;
in
{
  programs.codex = {
    enable = true;
  };

  # A linked worktree's git dirs live in the main repo, outside the workspace,
  # and Codex keeps the gitdir read-only unless it's named exactly. Grant them
  # per launch. Config keys split on dots, so key the rule on the nearest
  # dot-free ancestor and pass the git dirs as subpaths.
  programs.zsh.initContent = ''
    codex() {
      local git_dir common_dir base
      if git_dir=$(git rev-parse --path-format=absolute --git-dir 2>/dev/null) &&
        common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) &&
        [[ $git_dir != "$common_dir" ]]; then
        base=''${common_dir:h}
        while [[ $base == *.* ]]; do base=''${base:h}; done
        local c=''${common_dir#$base/} g=''${git_dir#$base/}
        command codex -c "permissions.${profile}.filesystem.$base={\"$c\"=\"write\", \"$c/hooks\"=\"read\", \"$c/config\"=\"read\", \"$g\"=\"write\"}" "$@"
      else
        command codex "$@"
      fi
    }
  '';

  # Codex writes project trust, MCP changes, and other runtime settings to
  # config.toml. Keep both it and the rules directory outside the Nix store.
  home.activation.codexMutableConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] (
    mergeConfig {
      name = "codex-config";
      path = "${config.home.homeDirectory}/.codex/config.toml";
      format = "toml";
      inherit settings;
    }
    + ''
      rules_path="${config.home.homeDirectory}/.codex/rules/nix-config.rules"
      mkdir -p "$(dirname "$rules_path")"
      if [ -L "$rules_path" ]; then
        rm -f "$rules_path"
      fi
      install -m 0644 ${commandRules} "$rules_path"
    ''
  );
}
