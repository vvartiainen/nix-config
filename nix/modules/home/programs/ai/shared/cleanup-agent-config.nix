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

  # Clear global MCP registrations before each CLI merges its settings.
  # User-managed skills and marketplace plugins survive activation.
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
