{
  lib,
  pkgs,
  config,
  ...
}:
let
  mergeConfig = import ../../../merge-config.nix { inherit lib pkgs config; };
in
{
  # T3 rewrites this file with provider settings and runtime markers. Merge
  # declared preferences, preserving accounts, extra instances and app state.
  home.activation.t3CodeConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] (mergeConfig {
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
      pullRequestMergeMethod = "merge";
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
      defaultRuntimeMode = "auto-accept-edits";
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
  });

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
