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
    model = "gpt-6.1-sol";
    model_reasoning_effort = "medium";
    plan_mode_reasoning_effort = "high";
    web_search = "live";
    shell_environment_policy.set = (permissions.agentCaches config).env;
    # Keep @ focused on files; plugins and skills remain available through $.
    features.mentions_v2 = false;
    # MCP servers come from the projects (`ct agents`), not ChatGPT apps.
    features.apps = false;
    # Skills come from the projects too, not the bundled system skills.
    skills.bundled.enabled = false;
    # Also record the individual choices shown by /skills. Use paths so a
    # project's skill with the same name is still available.
    skills.config = map (name: {
      path = "${config.home.homeDirectory}/.codex/skills/.system/${name}/SKILL.md";
      enabled = false;
    }) [
      "review-agent"
      "skill-creator"
      "skill-installer"
      "openai-docs"
      "imagegen"
    ];
    # Bundled plugins start off. The cleanup step resets global plugin choices
    # on switch; projects can still declare their own plugins.
    plugins = lib.genAttrs [
      "codex-app-tools@openai-bundled"
      "browser@openai-bundled"
      "unified-computer-use@openai-bundled"
      "computer-use@openai-bundled"
      "visualize@openai-bundled"
      "documents@openai-primary-runtime"
      "pdf@openai-primary-runtime"
      "spreadsheets@openai-primary-runtime"
      "presentations@openai-primary-runtime"
      "template-creator@openai-primary-runtime"
    ] (_: { enabled = false; });

    # Codex only supports built-in status line items (no custom command),
    # so mirror claude-statusline.sh as closely as possible.
    tui = {
      theme = "catppuccin-mocha";
      resume_cwd = "current";
      # Notify from background Herdr panes even while the terminal has focus.
      notification_condition = "always";
      presets."1" = {
        label = "Review";
        input = "/review";
      };
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
      schema = "codex";
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
