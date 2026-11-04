{
  config,
  lib,
  pkgs,
  ...
}:
let
  sketchybar = lib.optionalString pkgs.stdenv.hostPlatform.isDarwin "${pkgs.sketchybar}/bin/sketchybar";
  reporter = pkgs.writeShellScriptBin "nix-config-terminal-status" ''
    export NIX_CONFIG_SKETCHYBAR=${lib.escapeShellArg sketchybar}
    exec ${pkgs.python3}/bin/python3 ${./terminal-status.py} "$@"
  '';
  command = lib.getExe reporter;
  hook = app: state: kind: {
    type = "command";
    command = "${command} report ${app} ${state} ${kind}";
    timeout = 2;
  };
  group = app: state: kind: { hooks = [ (hook app state kind) ]; };
  common = app: {
    SessionStart = [ (group app "idle" "none") ];
    UserPromptSubmit = [ (group app "working" "none") ];
    PostToolUse = [ (group app "working" "none") ];
    Stop = [ (group app "done" "none") ];
    SessionEnd = [ (group app "clear" "none") ];
  };
  codexHooks = (common "codex") // {
    PermissionRequest = [ (group "codex" "blocked" "permission") ];
    PreToolUse = [
      (
        (group "codex" "blocked" "question")
        // {
          matcher = "^(request_user_input|request_user_input_async)$";
        }
      )
    ];
    Interrupt = [ (group "codex" "idle" "none") ];
  };
  claudeHooks = (common "claude") // {
    PermissionRequest = [ (group "claude" "blocked" "permission") ];
    PreToolUse = [
      (
        (group "claude" "blocked" "question")
        // {
          matcher = "AskUserQuestion";
        }
      )
    ];
    StopFailure = [ (group "claude" "error" "none") ];
  };
  copilotHook =
    state: kind:
    (builtins.removeAttrs (hook "copilot" state kind) [ "timeout" ])
    // {
      timeoutSec = 2;
    };
  copilotHooks = {
    sessionStart = [ (copilotHook "idle" "none") ];
    userPromptSubmitted = [ (copilotHook "working" "none") ];
    postToolUse = [ (copilotHook "working" "none") ];
    agentStop = [ (copilotHook "done" "none") ];
    sessionEnd = [ (copilotHook "clear" "none") ];
    errorOccurred = [ (copilotHook "error" "none") ];
    notification = [
      ((copilotHook "blocked" "permission") // { matcher = "permission_prompt"; })
      ((copilotHook "blocked" "question") // { matcher = "elicitation_dialog"; })
    ];
    preToolUse = [ ((copilotHook "blocked" "question") // { matcher = "ask_user"; }) ];
  };
  json = pkgs.formats.json { };
  codexConfig = json.generate "codex-terminal-status.json" { hooks = codexHooks; };
  claudeConfig = json.generate "claude-terminal-status.json" { hooks = claudeHooks; };
in
{
  # Hooks have captured stdout and may lack a controlling terminal. Capture
  # the launch terminal explicitly; do not inherit a parent agent's terminal.
  programs.zsh.initContent = ''
    _nix_config_agent_tty() {
      local terminal="" launch="$$-$RANDOM-$RANDOM"
      if [[ $TERM == xterm-kitty && -n $KITTY_WINDOW_ID && -z $TMUX && -t 1 ]]; then
        terminal=$(tty)
      fi
      {
        NIX_CONFIG_AGENT_TTY="$terminal" NIX_CONFIG_AGENT_LAUNCH="$launch" \
          NIX_CONFIG_AGENT_PID="$$" "$@"
      } always {
        ${command} clear "$launch" >/dev/null 2>&1
      }
    }
    claude() { _nix_config_agent_tty command claude "$@"; }
  '';

  programs.sketchybar.extraPackages = lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ reporter ];

  home.file."${config.programs.github-copilot-cli.configDir}/hooks/nix-config-terminal-status.json".source =
    json.generate "copilot-terminal-status.json" {
      version = 1;
      hooks = copilotHooks;
    };

  # Preserve vendor and user hooks, including other handlers for the same event.
  home.activation.agentTerminalStatus =
    lib.hm.dag.entryAfter
      [
        "claudeCodeConfig"
        "codexMutableConfig"
        "rexAgentHooks"
        "herdrAgentIntegrations"
      ]
      ''
        run ${command} install ${claudeConfig} ${lib.escapeShellArg "${config.programs.claude-code.configDir}/settings.json"}
        run ${command} install ${codexConfig} ${lib.escapeShellArg "${config.home.homeDirectory}/.codex/hooks.json"}
      '';
}
