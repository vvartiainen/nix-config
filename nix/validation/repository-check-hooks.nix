{
  lib,
  pkgs,
  repoRoot,
  ...
}:
let
  checker = import ./repository-checks.nix { inherit pkgs; };
  hook = event: {
    type = "command";
    command = "${lib.getExe checker} --hook ${event} --repository ${lib.escapeShellArg repoRoot}";
    timeout = 60;
  };
  common = {
    UserPromptSubmit = [ { hooks = [ (hook "prompt") ]; } ];
    Stop = [ { hooks = [ (hook "stop") ]; } ];
    SessionEnd = [ { hooks = [ (hook "end") ]; } ];
  };
  copilotHook = event: (builtins.removeAttrs (hook event) [ "timeout" ]) // { timeoutSec = 60; };
in
{
  agentHooks = {
    commandMarkers = [ "/bin/nix-config-check --hook " ];
    codex = common // {
      # Codex caps SessionEnd at three seconds; this only removes tracking state.
      SessionEnd = [ { hooks = [ ((hook "end") // { timeout = 3; }) ]; } ];
    };
    claude = common;
    copilot = {
      userPromptSubmitted = [ (copilotHook "prompt") ];
      agentStop = [ (copilotHook "stop") ];
      sessionEnd = [ (copilotHook "end") ];
    };
  };
}
