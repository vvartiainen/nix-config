{
  lib,
  pkgs,
  config,
  repoRoot,
  ...
}:
let
  mergeConfig = import ../../../merge-config.nix { inherit lib pkgs config; };
  permissions = import ../shared/permissions.nix { inherit lib config; };
  inherit (permissions)
    commands
    paths
    caches
    ;
  quote = s: ''"${s}"'';
  worktrees = "${config.home.homeDirectory}/.codex/worktrees";
  projects = builtins.dirOf repoRoot;
  # Local Git edits stay sandboxed. Other clients retain their own adapters.
  localGit = [
    [
      "git"
      "reset"
    ]
    [
      "git"
      "clean"
    ]
    [
      "git"
      "rebase"
    ]
  ];
  toCodexRule =
    decision: cmd:
    ''prefix_rule(pattern = [${lib.concatMapStringsSep ", " quote cmd}], decision = "${decision}")'';

  # Codex sandboxes read the whole disk by default; deny everything outside
  # the workspace except Codex's runtime set and the shared tool paths.
  permissionSettings = {
    approval_policy = "on-request";
    approvals_reviewer = "user";
    # Keep local-network and socket restrictions enforced by the proxy.
    features.network_proxy = true;

    default_permissions = "workspace-only";
    permissions.workspace-only = {
      # Built-in workspace writes and protected metadata; our :root deny
      # replaces its whole-disk reads. See docs/agent-permissions.md.
      extends = ":workspace";
      network = {
        enabled = true;
        # Ordinary internet access is allowed. Keep filesystem restrictions
        # and command review; "limited" also blocks non-GET methods.
        mode = "full";
        domains."*" = "allow";
        allow_local_binding = false;
        allow_upstream_proxy = false;
        # Keep Rex and other user-session control sockets out of the sandbox.
        dangerously_allow_all_unix_sockets = false;
        # Nix builds run through the daemon, outside the agent sandbox.
        unix_sockets.${paths.nixDaemonSocket} = "allow";
      };

      filesystem = {
        ":root" = "deny";
        # Codex's platform runtime bundle, not just ordinary read paths.
        # On macOS this includes /Applications reads and process scratch
        # writes under /tmp and /var/tmp. See docs/agent-permissions.md.
        ":minimal" = "read";
        # `:workspace` grants these, but keep them explicit next to the
        # `:root` deny.
        ":tmpdir" = "write";
        ":slash_tmp" = "write";

        ":workspace_roots" = {
          "." = "write";
          # `:workspace` keeps `.git` read-only, which blocks commits even
          # after approval. Keep hooks and config read-only: they run outside
          # the sandbox.
          ".git" = "write";
          ".git/hooks" = "read";
          ".git/config" = "read";
          "**/.env" = "deny";
          "**/.env.*" = "deny";
        }
        // lib.genAttrs paths.secretFiles (_: "deny");
      }
      // lib.genAttrs (paths.readonly ++ paths.runtime ++ paths.readable) (_: "read")
      // lib.genAttrs caches.writePaths (_: "write")
      // lib.genAttrs paths.denied (_: "deny")
      // lib.genAttrs (map (pattern: "${projects}/${pattern}") paths.workspaceSecrets) (_: "deny")
      // lib.genAttrs (map (pattern: "${worktrees}/${pattern}") (
        [
          "**/.env"
          "**/.env.*"
        ]
        ++ paths.secretFiles
      )) (_: "deny")
      // {
        # Match Claude's project reads without granting sibling writes. Linked
        # worktrees need to read Git metadata outside their workspace root.
        "${projects}" = "read";
        # App launches bypass the shell wrapper below. Worktrees of this
        # checkout still need its shared Git metadata to create commits.
        "${repoRoot}/.git" = "write";
        "${repoRoot}/.git/hooks" = "read";
        "${repoRoot}/.git/config" = "read";
        # Node's OpenSSL startup probes this even for local commands.
        "/System/Library/OpenSSL" = "read";
        # Managed worktrees can be created after the session starts, outside
        # its original workspace roots. Keep the grant within their directory.
        # Codex allows mid-path globs only for deny rules; linked worktrees
        # keep hooks and config in the main checkout's protected Git dir.
        "${worktrees}" = "write";
        "${config.home.homeDirectory}/.codex/skills" = "read";
        # Allow inspecting installed lifecycle hooks without permitting edits
        # to commands that execute outside the agent sandbox.
        "${config.home.homeDirectory}/.codex/hooks.json" = "read";

        # Nix probes the socket before selecting the daemon store. The
        # network allowlist above permits connecting, not filesystem probes.
        ${paths.nixDaemonSocket} = "read";
      };
    };
  };

  # Leave routine commands to the sandbox and on-request approval policy.
  # Explicit prompt rules also prompt inside the sandbox, while allow rules
  # can authorize leaving it. Host-control CLIs need review even inside it.
  commandRules = pkgs.writeText "codex-nix-config.rules" (
    lib.concatMapStringsSep "\n" (toCodexRule "prompt") (
      (builtins.filter (cmd: !(builtins.elem cmd localGit)) commands.review)
      ++ map (exe: [ exe ]) commands.hostExecutables
    )
    + "\n"
    + lib.concatMapStringsSep "\n" (toCodexRule "forbidden") commands.denied
    + "\n"
  );

  # Preserve security features when adding UI feature settings below.
  settings = lib.recursiveUpdate permissionSettings {
    model = "gpt-6.1-sol";
    model_reasoning_effort = "medium";
    plan_mode_reasoning_effort = "high";
    # Compact at 80% of the model's 500k-token context window, like the other
    # CLIs. The limit is in tokens, so revisit it when the model changes.
    model_auto_compact_token_limit = 400000;
    web_search = "live";
    shell_environment_policy.set = caches.env // {
      # Avoid macOS trust-store lookups from sandboxed Node commands. Keep
      # certificate verification and add the same Nix roots used by Go.
      NODE_USE_SYSTEM_CA = "0";
      NODE_EXTRA_CA_CERTS = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    };
    # Keep @ focused on files; plugins and skills remain available through $.
    features.mentions_v2 = false;
    # MCP servers come from the projects (`ct agents`), not ChatGPT apps.
    features.apps = false;
    # Custom skills are managed outside Nix; keep bundled system skills off.
    skills.bundled.enabled = false;
    # Also record the individual choices shown by /skills. Use paths so a
    # project's skill with the same name is still available.
    skills.config =
      map
        (name: {
          path = "${config.home.homeDirectory}/.codex/skills/.system/${name}/SKILL.md";
          enabled = false;
        })
        [
          "review-agent"
          "skill-creator"
          "skill-installer"
          "openai-docs"
          "imagegen"
        ];
    # Keep these bundled plugins off; private marketplace choices stay mutable.
    plugins =
      lib.genAttrs
        [
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
        ]
        (_: {
          enabled = false;
        });

    # Codex only supports built-in status line items (no custom command),
    # so mirror claude-statusline.sh as closely as possible.
    tui = {
      theme = "catppuccin-mocha";
      resume_cwd = "current";
      # Notify from background Herdr panes even while the terminal has focus.
      notification_condition = "always";
      presets = {
        "0" = {
          label = "Model";
          input = "/model";
        };
        "1" = {
          label = "Review";
          input = "/review";
        };
        "2" = {
          label = "Subagents";
          input = "/subagents";
        };
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
      keymap.chat = {
        open_presets = "alt-p";
        increase_reasoning_effort = [
          "alt-t"
          "alt-."
          "shift-up"
        ];
        decrease_reasoning_effort = [
          "alt-shift-t"
          "alt-,"
          "shift-down"
        ];
      };
    };
  };
  profile = permissionSettings.default_permissions;
in
{
  programs.codex = {
    enable = true;
    # The Homebrew cask provides the CLI; it updates sooner than nixpkgs.
    package = null;
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
      install -m 0644 ${commandRules} "$rules_path"
    ''
  );
}
