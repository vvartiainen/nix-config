{
  lib,
  pkgs,
  config,
  repoRoot,
  ...
}:
let
  jsonFormat = pkgs.formats.json { };
  jq = lib.getExe pkgs.jq;
  permissions = import ./permissions.nix { inherit lib; };
  hooks = import ./hooks.nix { inherit lib pkgs; };
  copilotHooksDir = "${config.programs.github-copilot-cli.configDir}/hooks";
  copilotHookPath = "${copilotHooksDir}/${hooks.copilot.hookFileName}";
  copilotHomeRel = lib.removePrefix "${config.home.homeDirectory}/" copilotHooksDir;
  staticCopilotHooks = jsonFormat.generate "github-copilot-cli-block-nix-apply.json" {
    version = 1;
    hooks.preToolUse = [
      {
        type = "command";
        exec = copilotHookPath;
        args = [
          "--format"
          "copilot"
        ];
        inherit (hooks.copilot) matcher timeoutSec;
      }
    ];
  };

  # Copilot CLI stores user-editable settings in settings.json and rewrites
  # that file in place. A home-manager symlink into the Nix store gets
  # replaced on the first CLI settings change, so keep the file writable and
  # merge Nix settings on activation instead.
  #
  # The home-manager `settings` option still writes config.json, which the CLI
  # now treats as runtime state (auth, plugins) and must remain writable.
  settings = {
    model = "gpt-5.6-sol";
    effortLevel = "medium";
    # Local sandboxing is experimental. PATH dirs are auto-granted read-only,
    # but Nix binaries resolve into the store and mise shims into XDG dirs.
    experimental = true;
    sandbox = {
      enabled = true;
      userPolicy.filesystem.readonlyPaths = permissions.sandboxReadonlyPaths config.xdg;
    };
    footer = {
      showModelEffort = true;
      showDirectory = true;
      showBranch = true;
      showContextWindow = true;
      showQuota = true;
      showAgent = true;
      showCodeChanges = false;
      showUsername = false;
      showCustom = true;
    };
    includeCoAuthoredBy = false;
    allowedUrls = permissions.urlDomains;
    disabledSkills = [ ];
    theme = "github";
    beep = true;
    notifications = true;
    scrollbar = true;
    voice.enabled = false;
    planModel = "gpt-5.6-sol";
    planEffortLevel = "medium";
    subagents.agents = {
      task = {
        model = "inherit";
        effortLevel = "medium";
        contextTier = "default";
      };
      "general-purpose".model = "inherit";
      "code-review".model = "inherit";
      research.model = "inherit";
      "security-review".model = "inherit";
    };
  };

  staticSettings = jsonFormat.generate "github-copilot-cli-settings.json" settings;
  staticLspSettings = jsonFormat.generate "github-copilot-cli-lsp.json" {
    lspServers.typescript = {
      command = "${config.xdg.dataHome}/mise/shims/tsc";
      args = [
        "--lsp"
        "--stdio"
      ];
      fileExtensions = {
        ".ts" = "typescript";
        ".tsx" = "typescriptreact";
        ".js" = "javascript";
        ".jsx" = "javascriptreact";
        ".mjs" = "javascript";
        ".cjs" = "javascript";
        ".mts" = "typescript";
        ".cts" = "typescript";
      };
    };
  };
  staticPermissions = jsonFormat.generate "github-copilot-cli-permissions.json" {
    locations.${repoRoot}.tool_approvals = [
      {
        kind = "commands";
        commandIdentifiers = permissions.copilot.commandIdentifiers;
      }
      { kind = "read"; }
    ]
    ++ permissions.copilot.mcp;
  };
in
{
  programs.github-copilot-cli = {
    enable = true;
  };

  home.file."${copilotHomeRel}/${hooks.copilot.hookFileName}".source = lib.getExe hooks.script;
  home.file."${copilotHomeRel}/block-nix-apply.json".source = staticCopilotHooks;

  home.activation.githubCopilotCliSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    merge_copilot_config() {
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

    merge_copilot_config \
      "${config.programs.github-copilot-cli.configDir}/settings.json" \
      ${staticSettings}
    merge_copilot_config \
      "${config.programs.github-copilot-cli.configDir}/lsp-config.json" \
      ${staticLspSettings}
    merge_copilot_config \
      "${config.programs.github-copilot-cli.configDir}/permissions-config.json" \
      ${staticPermissions}
  '';
}
