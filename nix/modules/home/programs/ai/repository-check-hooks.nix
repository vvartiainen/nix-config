{
  lib,
  pkgs,
  repoRoot,
  ...
}:
let
  checker = import ../../../../packages/repository-checks.nix { inherit pkgs; };
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
    codex = common;
    claude = common;
    copilot = {
      userPromptSubmitted = [ (copilotHook "prompt") ];
      agentStop = [ (copilotHook "stop") ];
      sessionEnd = [ (copilotHook "end") ];
    };
  };
}
