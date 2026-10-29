{
  lib,
  pkgs,
  config,
  ...
}:
let
  mergeConfig = import ../../merge-config.nix { inherit lib pkgs config; };
  permissions = import ./permissions.nix { inherit lib config; };
  inherit (permissions) commands;

  commandString = lib.concatStringsSep " ";
  # OpenCode has no OS sandbox, so routine runners also need approval.
  askCommands = commands.sandboxAsk ++ commands.routine;

  toBashRules =
    value: cmds:
    builtins.listToAttrs (
      map (cmd: {
        name = "${commandString cmd} *";
        inherit value;
      }) cmds
    );

  permissionSettings = {
    bash = {
      "*" = "ask";
    }
    // toBashRules "allow" commands.allowed
    // lib.genAttrs (map commandString commands.exact) (_: "allow")
    // toBashRules "ask" askCommands
    // lib.genAttrs (map commandString askCommands) (_: "ask")
    // toBashRules "deny" commands.denied;
    external_directory = {
      "*" = "ask";
      "/nix/store/**" = "allow";
    };
    read = {
      "*" = "allow";
      "*.env" = "deny";
      "*.env.*" = "deny";
      "*.env.example" = "allow";
    };
  };

  settings = {
    model = "openai/gpt-6.1-sol";
    provider.openai.models."gpt-6.1-sol".options.reasoningEffort = "medium";
    lsp.typescript = {
      command = [
        "${config.xdg.dataHome}/mise/shims/tsc"
        "--lsp"
        "--stdio"
      ];
      extensions = [
        ".ts"
        ".tsx"
        ".js"
        ".jsx"
        ".mjs"
        ".cjs"
        ".mts"
        ".cts"
      ];
    };
    permission = permissionSettings;
  };

  tuiSettings = {
    "$schema" = "https://opencode.ai/tui.json";
    theme = "catppuccin";
  };

  # OpenCode v2 reads cli.json with dotted action IDs. Retain tui.json above
  # for the legacy client.
  cliSettings = {
    theme.name = "catppuccin";
    keybinds = {
      "prompt.editor" = [
        "ctrl+g"
        "<leader>e"
      ];
      "session.first" = [
        "home"
        "alt+home"
      ];
      "model.list" = [
        "alt+p"
        "<leader>m"
      ];
    };
  };
in
{
  programs.opencode = {
    enable = true;
    package = null;
    # OpenCode updates opencode.json and cli.json through commands such as
    # `opencode mcp add`. Keep them app-owned; Home Manager loads these
    # settings as separate layers.
    mutableSettings = true;
    inherit settings;
    cli = cliSettings;
  };

  home.sessionVariables.OPENCODE_EXPERIMENTAL_LSP_TOOL = "true";

  home.activation.opencodeConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] (mergeConfig {
    name = "opencode-tui";
    schema = "opencode-tui";
    path = "${config.xdg.configHome}/opencode/tui.json";
    settings = tuiSettings;
  });
}
