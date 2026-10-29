{
  lib,
  pkgs,
  ...
}:
let
  cleanup = pkgs.writers.writePython3Bin "cleanup-agent-config" {
    libraries = [
      pkgs.python3Packages.json5
      pkgs.python3Packages.tomlkit
      (import ../../agent-config-validation.nix { inherit pkgs; })
    ];
  } ./cleanup-agent-config.py;
in
{
  home.packages = [ cleanup ];

  # Clear user-level tools before applying each CLI's declared settings.
  home.activation.agentToolsCleanup =
    lib.hm.dag.entryBetween
      [
        "claudeCodeConfig"
        "codexMutableConfig"
        "cursorCliConfig"
        "githubCopilotCliSettings"
        "opencodeConfig"
      ]
      [ "linkGeneration" ]
      ''
        run ${lib.getExe cleanup}
      '';
}
