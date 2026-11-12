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
      (import ../../../../../validation/agent-config-validation.nix { inherit pkgs; })
    ];
  } ./cleanup-agent-config.py;
in
{
  home.packages = [ cleanup ];

  # Clear global tools before Home Manager restores Nix-declared skills and
  # each CLI merges its settings. Force-owned skills pass checkLinkTargets.
  home.activation.agentToolsCleanup =
    lib.hm.dag.entryBetween
      [
        "linkGeneration"
        "claudeCodeConfig"
        "codexMutableConfig"
        "cursorCliConfig"
        "githubCopilotCliSettings"
      ]
      [ "writeBoundary" ]
      ''
        run ${lib.getExe cleanup}
      '';
}
