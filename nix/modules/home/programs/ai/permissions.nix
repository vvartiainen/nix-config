{ lib }:
let
  inherit (lib) concatMapStringsSep concatStringsSep;

  # Canonical command prefixes allowed without prompting. Each entry is argv.
  allowedCommands = [
    [ "git" "status" ]
    [ "git" "diff" ]
    [ "grep" ]
    [ "printf" ]
    [ "npm" "run" "test" ]
    [ "npm" "run" "build" ]
    [ "npm" "run" "format" ]
    [ "npm" "test" ]
    [ "npx" "vitest" ]
    [ "npx" "tsc" ]
    [ "npx" "eslint" ]
    [ "terraform" "fmt" ]
    [ "terraform" "validate" ]
    [ "just" "eval-system" ]
    [ "just" "build-system" ]
    [ "just" "build" ]
    [ "just" "check" ]
    [ "just" "show" ]
    [ "nix" "fmt" ]
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
    if args == [ ] then "Shell(${bin}:*)" else "Shell(${bin}:${commandString args} *)";

  quote = s: ''"${s}"'';
  toCodexRule =
    cmd: ''prefix_rule(pattern = [${concatMapStringsSep ", " quote cmd}], decision = "allow")'';
in
{
  inherit urlDomains;

  sandboxReadonlyPaths = xdg: [
    "/nix/store"
    "${xdg.dataHome}/mise"
    "${xdg.configHome}/mise"
  ];

  cursor = {
    allow =
      (map toCursorShell allowedCommands)
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
    bash =
      { "*" = "ask"; }
      // builtins.listToAttrs (
        map (cmd: {
          name = "${commandString cmd} *";
          value = "allow";
        }) allowedCommands
      );
    read = {
      "*" = "allow";
      "*.env" = "deny";
      "*.env.*" = "deny";
      "*.env.example" = "allow";
    };
  };

  codexRules = concatMapStringsSep "\n" toCodexRule allowedCommands + "\n";
}
