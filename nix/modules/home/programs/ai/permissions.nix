{ lib }:
let
  inherit (lib) concatMapStringsSep concatStringsSep;

  # Canonical command prefixes allowed without prompting. Each entry is argv.
  allowedCommands = [
    [
      "git"
      "status"
    ]
    [
      "git"
      "diff"
    ]
    [
      "git"
      "add"
    ]

    [ "grep" ]
    [ "printf" ]
    [
      "npm"
      "run"
      "test"
    ]
    [
      "npm"
      "run"
      "build"
    ]
    [
      "npm"
      "run"
      "format"
    ]
    [
      "npm"
      "test"
    ]
    [
      "npx"
      "vitest"
    ]
    [
      "npx"
      "tsc"
    ]
    [
      "npx"
      "eslint"
    ]
    [
      "terraform"
      "fmt"
    ]
    [
      "terraform"
      "validate"
    ]
    [
      "just"
      "eval-system"
    ]
    [
      "just"
      "build-system"
    ]
    [
      "just"
      "build"
    ]
    [
      "just"
      "check"
    ]
    [
      "just"
      "show"
    ]
    [
      "nix"
      "fmt"
    ]
    [ "rg" ]
    [ "tail" ]
    [ "head" ]
    [ "wc" ]
    [ "base64" ]
    [ "ls" ]
  ];

  mcpServers = [ "nixos" ];

  urlDomains = [
    "github.com"
    "*.github.com"
    "*.githubusercontent.com"
    "github.io"
    "*.github.io"
  ];

  commandString = concatStringsSep " ";

  toCursorShell =
    cmd:
    let
      bin = builtins.head cmd;
      args = builtins.tail cmd;
    in
    if args == [ ] then
      [ "Shell(${bin}:*)" ]
    else
      [
        "Shell(${bin}:${commandString args})"
        "Shell(${bin}:${commandString args} *)"
      ];

  quote = s: ''"${s}"'';
  toCodexRule =
    cmd: ''prefix_rule(pattern = [${concatMapStringsSep ", " quote cmd}], decision = "allow")'';

  sandboxReadonlyPaths = config: [
    "/nix/store"
    "/opt/homebrew"
    "${config.xdg.dataHome}/mise"
    "${config.xdg.configHome}/mise"
    # Package stores outside the sandboxes' built-in grants (e.g. aube's
    # virtual store, which project node_modules symlink into).
    config.xdg.cacheHome
    "${config.home.homeDirectory}/.gitconfig"
  ];
in
{
  inherit urlDomains sandboxReadonlyPaths;

  # Codex sandboxes read the whole disk by default; deny everything outside
  # the workspace except Codex's runtime set and the tool paths above.
  codexPermissions = config: {
    default_permissions = "workspace-only";
    permissions.workspace-only = {
      extends = ":workspace";
      filesystem = {
        ":root" = "deny";
        ":minimal" = "read";
        ":workspace_roots" = {
          "." = "write";
          "**/.env" = "deny";
          "**/.env.*" = "deny";
        };
      }
      // lib.genAttrs (sandboxReadonlyPaths config) (_: "read");
    };
  };

  cursor = {
    allow =
      (lib.concatMap toCursorShell allowedCommands)
      ++ [ "Read(**)" ]
      ++ map (domain: "WebFetch(${domain})") urlDomains
      ++ map (name: "Mcp(${name}:*)") mcpServers;
    deny = [
      "Read(.env)"
      "Read(.env.*)"
      "Read(**/.env)"
      "Read(**/.env.*)"
    ];
  };

  copilot = {
    commandIdentifiers = map (cmd: "${commandString cmd}:*") allowedCommands;
    mcp = map (name: {
      kind = "mcp";
      serverName = name;
      toolName = null;
    }) mcpServers;
  };

  opencode = {
    bash = {
      "*" = "ask";
    }
    // builtins.listToAttrs (
      map (cmd: {
        name = "${commandString cmd} *";
        value = "allow";
      }) allowedCommands
    );
    external_directory = "ask";
    read = {
      "*" = "allow";
      "*.env" = "deny";
      "*.env.*" = "deny";
      "*.env.example" = "allow";
    };
  };

  codexRules = concatMapStringsSep "\n" toCodexRule allowedCommands + "\n";
}
