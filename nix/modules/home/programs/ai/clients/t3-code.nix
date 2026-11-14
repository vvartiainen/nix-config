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
  # only our defaults, preserving accounts, extra instances and app state.
  home.activation.t3CodeConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] (
    mergeConfig {
      name = "t3-code";
      path = "${config.home.homeDirectory}/.t3/userdata/settings.json";
      settings = {
        defaultRuntimeMode = "auto-accept-edits";
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
            config.binaryPath = "${config.home.homeDirectory}/.local/bin/claude";
          };
          pi = {
            driver = "pi";
            config.binaryPath = "${config.home.profileDirectory}/bin/pi";
          };
        };
      };
    }
  );
}
