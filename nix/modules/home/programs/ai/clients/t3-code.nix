{
  lib,
  pkgs,
  config,
  ...
}:
let
  jsonFormat = pkgs.formats.json { };
  mergeConfig = import ../../../merge-config.nix { inherit lib pkgs config; };
  keybindings = jsonFormat.generate "t3-code-keybindings.json" (
    map (binding: binding // { when = "!terminalFocus && !previewFocus"; }) [
      {
        key = "ctrl+shift+j";
        command = "thread.next";
      }
      {
        key = "ctrl+shift+k";
        command = "thread.previous";
      }
      {
        key = "alt+p";
        command = "modelPicker.toggle";
      }
      {
        key = "alt+t";
        command = "composer.increaseEffort";
      }
      {
        key = "alt+shift+t";
        command = "composer.decreaseEffort";
      }
      {
        key = "ctrl+shift+x";
        command = "thread.stop";
      }
    ]
  );
  mergeKeybindings = pkgs.writeShellScript "t3-code-keybindings" ''
    set -eu
    destination="$1"
    ${pkgs.coreutils}/bin/mkdir -p "$(dirname "$destination")"
    current=/dev/null
    if [ -f "$destination" ]; then current="$destination"; fi
    temporary=$(${pkgs.coreutils}/bin/mktemp "$destination.XXXXXX")
    trap '${pkgs.coreutils}/bin/rm -f "$temporary"' EXIT
    ${pkgs.jq}/bin/jq -s --slurpfile managed ${keybindings} '
      (if length == 0 then [] else .[0] end) |
      if type != "array" then error("T3 keybindings must be an array") else . end |
      map(select(.command as $command | $managed[0] | all(.command != $command)))
      + $managed[0]
    ' "$current" > "$temporary"
    ${pkgs.coreutils}/bin/mv "$temporary" "$destination"
  '';
  # T3 publishes environment themes from regular files in this directory and
  # skips symlinks, so activation copies the palette into place.
  themePath = "${config.home.homeDirectory}/.t3/userdata/themes/catppuccin-mocha.json";
  theme = jsonFormat.generate "t3-code-catppuccin-mocha.json" {
    version = 1;
    id = "catppuccin-mocha";
    name = "Catppuccin Mocha";
    appearance = "dark";
    colors = {
      # Base colors: base, mantle, crust, surface0-2, overlay0-1, subtext0-1.
      canvas = "#1e1e2e";
      chrome = "#181825";
      surface = "#1e1e2e";
      surfaceRaised = "#313244";
      surfaceOverlay = "#45475a";
      border = "#45475a";
      input = "#313244";
      text = "#cdd6f4";
      textMuted = "#a6adc8";
      secondaryLabel = "#bac2de";
      placeholder = "#6c7086";
      iconMuted = "#7f849c";
      muted = "#313244";
      mutedForeground = "#a6adc8";
      secondary = "#45475a";
      secondaryForeground = "#cdd6f4";
      # Accent: mauve, with lavender for hover states.
      focus = "#cba6f7";
      accent = "#cba6f7";
      accentForeground = "#1e1e2e";
      accentSurface = "#cba6f7";
      accentSurfaceForeground = "#1e1e2e";
      update = "#cba6f7";
      updateForeground = "#1e1e2e";
      updateSurface = "#cba6f7";
      # Status: red, yellow and peach.
      error = "#f38ba8";
      errorForeground = "#1e1e2e";
      errorSurface = "#f38ba8";
      warning = "#f9e2af";
      warningForeground = "#1e1e2e";
      warningSurface = "#f9e2af";
      searchMatchBackground = "#f9e2af";
      searchMatchForeground = "#1e1e2e";
      searchMatchActiveBackground = "#fab387";
      searchMatchActiveForeground = "#1e1e2e";
      # Conversation and code surfaces.
      messageSurface = "#181825";
      messageForeground = "#cdd6f4";
      messageAction = "#cba6f7";
      messageActionForeground = "#1e1e2e";
      messageActionHover = "#b4befe";
      codeBackground = "#181825";
      codeForeground = "#cdd6f4";
      # Sidebar and toolbar.
      sidebar = "#11111b";
      sidebarForeground = "#cdd6f4";
      sidebarMutedForeground = "#a6adc8";
      sidebarControlSurface = "#1e1e2e";
      sidebarRowHover = "#313244";
      sidebarRowActive = "#45475a";
      sidebarRowSelected = "#585b70";
      sidebarBorder = "#45475a";
      toolbar = "#181825";
      toolbarForeground = "#cdd6f4";
      toolbarBorder = "#45475a";
      toolbarControl = "#313244";
      toolbarControlForeground = "#cdd6f4";
      toolbarControlHover = "#45475a";
      # Terminal.
      terminalBackground = "#11111b";
      terminalForeground = "#cdd6f4";
      terminalCursor = "#cba6f7";
      terminalSelection = "#45475a";
      terminalScrollbar = "#45475a";
      terminalScrollbarHover = "#585b70";
    };
  };
  publishTheme = pkgs.writeShellScript "t3-code-theme" ''
    set -eu
    destination="$1"
    ${pkgs.coreutils}/bin/mkdir -p "$(dirname "$destination")"
    temporary=$(${pkgs.coreutils}/bin/mktemp "$destination.XXXXXX")
    trap '${pkgs.coreutils}/bin/rm -f "$temporary"' EXIT
    ${pkgs.coreutils}/bin/install -m 0644 ${theme} "$temporary"
    ${pkgs.coreutils}/bin/mv "$temporary" "$destination"
  '';
  serverConfig = mergeConfig {
    name = "t3-code";
    path = "${config.home.homeDirectory}/.t3/userdata/settings.json";
    settings = {
      addProjectBaseDirectory = "~/prog";
      defaultAutoPull = true;
      defaultModelSelection = {
        instanceId = "claudeAgent";
        model = "claude-opus-5-5";
      };
      defaultThreadEnvMode = "worktree";
      # Clients adopt the published Catppuccin Mocha theme once and keep their
      # own later choice. Bump the timestamp to apply it again.
      defaultTheme = "catppuccin-mocha";
      defaultThemeSetAt = "2026-11-15T02:37:03.000Z";
      fallbackModelSelection = {
        instanceId = "codex";
        model = "gpt-6.1-sol";
        options = [
          {
            id = "reasoningEffort";
            value = "medium";
          }
          {
            id = "serviceTier";
            value = "default";
          }
        ];
      };
      favorites = [
        {
          model = "deepseek/deepseek-flash";
          provider = "pi";
        }
        {
          model = "gpt-6.1-sol";
          provider = "codex";
        }
        {
          model = "gpt-6-astra";
          provider = "codex";
        }
        {
          model = "claude-opus-5-5";
          provider = "claudeAgent";
        }
        {
          model = "claude-fable-5-2";
          provider = "claudeAgent";
        }
      ];
      idleCompaction = "beforeCacheExpires";
      projectSettingsFolded = true;
      # The forge allows rebase merges only, so every client rebases; this
      # declares the intent and covers other hosts and projects. See
      # docs/design/t3-code.md.
      pullRequestMergeMethod = "rebase";
      removeAgentCreditsOnMerge = true;
      reviewGuideModelSelection = {
        instanceId = "codex";
        model = "gpt-6.1-sol";
      };
      reviewGuidesEnabled = true;
      sidebarAutoSettleAfterDays = null;
      sourceControlWriterModelSelection = {
        instanceId = "pi";
        model = "deepseek/deepseek-flash";
      };
      textGenerationModelSelection = {
        instanceId = "pi";
        model = "deepseek/deepseek-flash";
      };
      providerModelPreferences = {
        opencode = {
          hiddenModels = [
            "github-copilot/auto"
            "opencode/beam-free"
            "opencode/big-pickle"
            "github-copilot/claude-haiku-4.5"
            "github-copilot/claude-haiku-5.5"
            "github-copilot/claude-opus-4.8"
            "github-copilot/claude-opus-4.8-fast"
            "github-copilot/claude-opus-5"
            "github-copilot/claude-opus-5.5"
            "github-copilot/claude-sonnet-5"
            "github-copilot/claude-sonnet-5.5"
            "deepseek/deepseek-v4-pro"
            "opencode/deepseek-v4.1-flash-free"
            "opencode/flint-40b-free"
            "github-copilot/gemini-3.8-flash"
            "github-copilot/gemini-4-argon"
            "github-copilot/gemini-4-carbon"
            "github-copilot/gemini-4-hydrogen"
            "opencode/glm-5.3-flash-free"
            "github-copilot/gpt-5.3-codex"
            "openai/gpt-5.6-cyber"
            "openai/gpt-5.6-luna"
            "github-copilot/gpt-5.6-luna"
            "openai/gpt-5.6-luna-fast"
            "openai/gpt-5.6-sol"
            "github-copilot/gpt-5.6-sol"
            "openai/gpt-5.6-sol-fast"
            "openai/gpt-5.6-terra"
            "github-copilot/gpt-5.6-terra"
            "openai/gpt-5.6-terra-fast"
            "openai/gpt-6-astra"
            "github-copilot/gpt-6-astra"
            "openai/gpt-6-astra-fast"
            "openai/gpt-6-astra-ultrafast"
            "openai/gpt-6-luna"
            "github-copilot/gpt-6-luna"
            "openai/gpt-6-luna-fast"
            "openai/gpt-6-sol"
            "github-copilot/gpt-6-sol"
            "openai/gpt-6-sol-fast"
            "openai/gpt-6.1-sol"
            "github-copilot/gpt-6.1-sol"
            "openai/gpt-6.1-sol-fast"
            "openai/gpt-6.1-sol-ultrafast"
            "openai/gpt-6.1-terra"
            "github-copilot/gpt-6.1-terra"
            "openai/gpt-6.1-terra-fast"
            "github-copilot/grok-4.6"
            "github-copilot/grok-4.7"
            "opencode/iceman-free"
            "opencode/inkling-2-small-free"
            "opencode/longcat-2.5-free"
            "github-copilot/mai-code-1.1-flash"
            "opencode/mimo-v2.6-flash-free"
            "opencode/minimax-m3.1-flash-free"
            "opencode/nemotron-3.5-lightning-free"
            "opencode/nemotron-3.5-super-vl-free"
          ];
        };
        pi = {
          hiddenModels = [
            "default"
            "deepseek/deepseek-v4-pro"
            "openai-codex/gpt-5.6-luna"
            "openai-codex/gpt-5.6-sol"
            "openai-codex/gpt-5.6-terra"
            "openai-codex/gpt-6-astra"
            "openai-codex/gpt-6-luna"
            "openai-codex/gpt-6-sol"
            "openai-codex/gpt-6.1-sol"
            "openai-codex/gpt-6.1-terra"
          ];
        };
      };
      # Let provider automatic review handle routine approval requests.
      # T3 has no per-provider or per-instance permission default.
      defaultRuntimeMode = "auto";
      # Settle a thread once every linked pull request has merged.
      sidebarAutoSettleOnMerge = true;
      storageCleanup = {
        # Remove worktrees whose pull request commits reached the remote
        # default branch, including squash and rebase merges while the
        # worktree still sits at the pull request's last commit.
        worktreeOnMerge = true;
        worktreeOnDelete = true;
        worktreeUnchanged = true;
      };
      providerInstances = {
        codex = {
          driver = "codex";
          config = {
            # Use our installed CLI rather than T3's managed tool download.
            setupMode = "existing";
            binaryPath = "/opt/homebrew/bin/codex";
            # T3's legacy sandbox overrides can conflict with custom Codex
            # permission profiles and abort macOS shells (T3 issue #16458).
            # This applies only to T3; the normal CLI keeps its custom profile.
            launchArgs = "-c 'default_permissions=\":workspace\"'";
          };
        };
        claudeAgent = {
          driver = "claudeAgent";
          config = {
            binaryPath = "${config.home.homeDirectory}/.local/bin/claude";
            autoCompactWindow = "400000";
          };
        };
        opencode = {
          driver = "opencode";
          enabled = true;
        };
        pi = {
          enabled = true;
          driver = "pi";
          config.binaryPath = "${config.home.profileDirectory}/bin/pi";
        };
      };
    };
  };
in
{
  # Merge shortcuts and settings into the files T3 also writes.
  home.activation.t3CodeConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] (
    ''
      run ${publishTheme} ${lib.escapeShellArg themePath}
    ''
    + serverConfig
    + ''
      run ${mergeKeybindings} ${lib.escapeShellArg "${config.home.homeDirectory}/.t3/userdata/keybindings.json"}
    ''
  );

  home.activation.t3CodeClientConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] (mergeConfig {
    name = "t3-code-client";
    path = "${config.home.homeDirectory}/.t3/userdata/client-settings.json";
    settings = {
      notificationMode = "notifications-and-sound";
      inAppNotificationsEnabled = true;
      browserLinkTarget = "app";
      confirmQuit = "direct";
      proactivePanelsEnabled = true;
      threadDetailsItems.openIn = false;
    };
  });
}
