{
  lib,
  pkgs,
  config,
  ...
}:
let
  permissions = import ../shared/permissions.nix { inherit lib config; };
  inherit (permissions) commands paths;
  commandString = cmd: builtins.unsafeDiscardStringContext (lib.concatStringsSep " " cmd);
  rule = action: resource: effect: { inherit action resource effect; };
  shellRules = effect: cmds: map (cmd: rule "shell" "${commandString cmd} *" effect) cmds;
  # V2 evaluates ordered rules, last match wins. Never route project runners
  # through an allowlist without an OS sandbox.
  permissionSettings = [
    (rule "shell" "*" "ask")
    (rule "external_directory" "*" "ask")
    (rule "external_directory" "/nix/store/*" "allow")
    (rule "read" "*" "allow")
    (rule "edit" "*" "allow")
  ]
  ++ shellRules "allow" commands.inspection
  ++ map (cmd: rule "shell" (commandString cmd) "allow") commands.exact
  ++ shellRules "ask" (
    commands.development ++ commands.review ++ map (exe: [ exe ]) commands.hostExecutables
  )
  ++ shellRules "allow" commands.hostInspection
  ++ map (cmd: rule "shell" (commandString cmd) "allow") commands.hostExact
  ++ shellRules "deny" commands.denied
  ++ map (pattern: rule "shell" pattern "deny") commands.deniedPatterns
  ++ lib.concatMap (
    path:
    lib.concatMap
      (action: [
        (rule action path "deny")
        (rule action "${path}/*" "deny")
      ])
      [
        "read"
        "edit"
        "external_directory"
      ]
  ) paths.denied
  ++
    lib.concatMap
      (pattern: [
        (rule "read" pattern "deny")
        (rule "edit" pattern "deny")
      ])
      (
        [
          "*.env"
          "*.env.*"
          "*.pem"
          "*.key"
        ]
        ++ paths.workspaceSecrets
      )
  ++ [
    (rule "edit" "*/.git/config" "deny")
    (rule "edit" "*/.git/hooks/*" "deny")
  ];

  settings = {
    model = "deepseek/deepseek-flash";
    provider.openai.models."gpt-6.1-sol".options.reasoningEffort = "medium";
    lsp.typescript = {
      command = [
        (lib.getExe pkgs.typescript)
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
    permissions = permissionSettings;
    # The default, kept explicit like the other CLIs.
    compaction.auto = true;
  };

  # OpenCode v2 reads cli.json with dotted action IDs.
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
}
