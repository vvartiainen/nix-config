# Apply to the fixture darwinConfiguration; all identity and paths are synthetic.
darwin:
let
  inherit (darwin) pkgs;
  config = darwin.config.home-manager.users.agent;
  policy = import ../../nix/modules/home/programs/ai/shared/permissions.nix {
    inherit config;
    inherit (darwin.pkgs) lib;
  };
  piPolicy =
    config.home.file."/Users/agent/.pi/agent/extensions/pi-permission-system/config.json".text;
  # Match the configured extension pin; a version update must review the hash
  # and rerun the native loader/schema/policy checks, not just our hook tests.
  extension = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@gotgenes/pi-permission-system/-/pi-permission-system-42.0.0.tgz";
    hash = "sha256-GQSdksyfY9/Y4u/8QE9y4kSO2mXESk9no7sUqjmNsWs=";
  };
  piDir = "${pkgs.pi-coding-agent}/lib/node_modules/pi-monorepo";
  piCheck =
    assert builtins.elem "npm:@gotgenes/pi-permission-system@42.0.0"
      config.programs.pi-coding-agent.settings.packages;
    pkgs.runCommand "pi-permission-policy-check" { } ''
      tar -xzf ${extension}
      ln -s ${piDir}/node_modules package/node_modules
      export HOME="$TMPDIR"
      ${pkgs.nodejs}/bin/node ${./test_pi_permissions.mjs} ${piDir} "$PWD/package" ${pkgs.writeText "pi-permissions.json" piPolicy}
      touch "$out"
    '';
in
{
  inherit (policy) commands paths;
  pi = builtins.fromJSON piPolicy;
  piCheck = piCheck.drvPath;
  opencode = config.programs.opencode.settings.permissions;
  hooks = config.agentHooks;
  launch = config.programs.zsh.initContent;
  codex = config.home.activation.codexMutableConfig.data;
  claude = config.home.activation.claudeCodeConfig.data;
  cursor = config.home.activation.cursorCliConfig.data;
  copilot = config.home.activation.githubCopilotCliSettings.data;
}
