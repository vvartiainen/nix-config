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
      "terraform"
      "fmt"
    ]
    [
      "nix"
      "eval"
    ]

    [ "tail" ]
    [ "head" ]
    [ "wc" ]
    [ "base64" ]
    [ "ls" ]
    [ "echo" ]
    [ "pwd" ]
    [ "which" ]
    [ "date" ]
    [ "uname" ]
    [ "file" ]
    [ "stat" ]
    [ "basename" ]
    [ "dirname" ]
    [ "realpath" ]
    [ "cat" ]
    [ "diff" ]
    [ "cut" ]
    [ "tr" ]
    [ "jq" ]
    [
      "git"
      "log"
    ]
    [
      "git"
      "show"
    ]
    [
      "git"
      "blame"
    ]
    [
      "git"
      "ls-files"
    ]
    [
      "git"
      "rev-parse"
    ]
    [
      "nix"
      "flake"
      "show"
    ]
    [
      "nix"
      "flake"
      "metadata"
    ]
    [
      "nix"
      "path-info"
    ]
    [
      "nix"
      "why-depends"
    ]
    [
      "nix"
      "derivation"
      "show"
    ]
    [
      "nix"
      "log"
    ]
    [
      "gh"
      "pr"
      "view"
    ]
    [
      "gh"
      "pr"
      "diff"
    ]
    [
      "gh"
      "pr"
      "checks"
    ]
    [
      "gh"
      "issue"
      "view"
    ]
    [
      "gh"
      "run"
      "view"
    ]
    [
      "mise"
      "ls"
    ]
    [
      "mise"
      "current"
    ]
    [
      "mise"
      "which"
    ]
    [
      "mise"
      "where"
    ]
  ];

  # Commands allowed only exactly as written; their prefixes would also allow
  # e.g. `git branch -D` or `git remote add`. Codex only supports prefix
  # rules, so it doesn't get these.
  exactCommands = [
    [
      "git"
      "branch"
      "--show-current"
    ]
    [
      "git"
      "remote"
      "-v"
    ]
  ];

  # Broad command wrappers and daemon-backed Nix commands still need review
  # inside Codex's sandbox. `nix fmt` can build the flake's formatter.
  codexAskCommands = [
    [ "just" ]
    [
      "npm"
      "run"
    ]
    [ "npx" ]
    [
      "nix"
      "fmt"
    ]
    [
      "nix"
      "build"
    ]
  ];

  # Other CLIs also ask for these project-code runners. Codex leaves them to
  # its sandbox and on-request escalation; don't grant unsandboxed allows.
  askCommands = codexAskCommands ++ [
    [
      "npm"
      "test"
    ]
    [
      "cargo"
      "test"
    ]
    [
      "terraform"
      "validate"
    ]
  ];

  # Command prefixes that are never auto-approved. Prefix denies can be
  # bypassed (`sh -c`, absolute paths), but those forms still prompt or run
  # sandboxed; this keeps these from being approved by accident.
  deniedCommands = [
    [ "op" ]
    [ "security" ]
    [
      "gh"
      "auth"
    ]
    [
      "gh"
      "api"
    ]
    [ "sudo" ]
    [ "darwin-rebuild" ]
    [
      "just"
      "switch"
    ]
    [
      "git"
      "push"
      "--force"
    ]
    [
      "mise"
      "trust"
    ]
  ];

  # Credential files denied for reads, relative to the home directory.
  homeSecretPaths = [
    ".ssh/**"
    ".config/op/**"
    ".config/gh/**"
    ".aws/**"
    ".gnupg/**"
    ".netrc"
    ".npmrc"
  ];

  secretFilePatterns = [
    "**/*.pem"
    "**/*.key"
  ];

  # homeSecretPaths as plain paths, for sandboxes that don't take globs.
  sandboxDeniedPaths =
    config: map (path: "${config.home.homeDirectory}/${lib.removeSuffix "/**" path}") homeSecretPaths;

  # The catalog's MCP servers (mcp.nix), whose tools are allowed without
  # prompting where a project turns them on.
  mcpServers = config: lib.attrNames config.agents.mcpServers;

  # Domains the agents may fetch pages from.
  fetchDomains = [
    "github.com"
    "*.github.com"
    "*.githubusercontent.com"
    "github.io"
    "*.github.io"
    "docs.aws.amazon.com"
    # Nix
    "nixos.org"
    "*.nixos.org"
    "nix.dev"
    "noogle.dev"
    "mynixos.com"
    # Tooling
    "mise.jdx.dev"
    "neovim.io"
    "developer.hashicorp.com"
    "registry.terraform.io"
    # Languages
    "developer.mozilla.org"
    "nodejs.org"
    "www.typescriptlang.org"
    "docs.python.org"
    "docs.rs"
    "pkg.go.dev"
    # Registries
    "www.npmjs.com"
    "registry.npmjs.org"
    "pypi.org"
    "crates.io"
    # Schemas
    "json.schemastore.org"
    "www.schemastore.org"
  ];

  # Package download hosts only. npm's registry and crates.io also accept
  # uploads, so access to them needs approval. This is a host boundary, not
  # a guarantee against every possible data channel to an allowed service.
  sandboxNetworkDomains = [
    # Nix's global flake registry, fetched to resolve `nixpkgs#…`.
    "channels.nixos.org"
    "pypi.org"
    "files.pythonhosted.org"
    "index.crates.io"
    "static.crates.io"
    "proxy.golang.org"
    "sum.golang.org"
    # mise's version index; installs still run outside the sandbox.
    "mise-versions.jdx.dev"
    # JSON schemas; json.schemastore.org redirects to www.
    "json.schemastore.org"
    "www.schemastore.org"
  ];

  # Sandboxed package managers get their own writable caches. Unsandboxed
  # builds trust the user's normal caches, so writes there would escape the
  # sandbox.
  agentCaches =
    config:
    let
      dir = name: "${config.home.homeDirectory}/.cache/${name}-agent";
    in
    {
      env = {
        NIX_CACHE_HOME = dir "nix";
        CARGO_HOME = dir "cargo";
        GOCACHE = "${dir "go"}/build";
        GOMODCACHE = "${dir "go"}/mod";
        MISE_CACHE_DIR = dir "mise";
        npm_config_cache = dir "npm";
      };
      writePaths = map dir [
        "nix"
        "cargo"
        "go"
        "mise"
        "npm"
      ];
    };

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
    decision: cmd:
    ''prefix_rule(pattern = [${concatMapStringsSep ", " quote cmd}], decision = "${decision}")'';

  toOpencodeRules =
    value: cmds:
    builtins.listToAttrs (
      map (cmd: {
        name = "${commandString cmd} *";
        inherit value;
      }) cmds
    );

  sandboxReadonlyPaths = config: [
    "/nix/store"
    "/opt/homebrew"
    "${config.xdg.dataHome}/mise"
    "${config.xdg.configHome}/mise"
    # Package stores outside the sandboxes' built-in grants: aube's virtual
    # store, which project node_modules symlink into.
    "${config.xdg.cacheHome}/aube/virtual-store"
    "${config.xdg.configHome}/git"
  ];

  # Paths git and Nix probe at startup, for sandboxes that deny reads outside
  # their grants.
  toolRuntimePaths = config: [
    # Git probes ~/.gitconfig even when Home Manager writes the config
    # under ~/.config/git. A denied probe prevents all git commands.
    "${config.home.homeDirectory}/.gitconfig"

    # PATH entries reach Nix tools through these profile symlinks.
    "${config.home.homeDirectory}/.nix-profile"
    "/etc/profiles/per-user/${config.home.username}"
    "/run/current-system"
    "/nix/var/nix/profiles"
    "/etc/nix"
  ];

  nixDaemonSocket = "/nix/var/nix/daemon-socket/socket";
in
{
  inherit
    agentCaches
    fetchDomains
    nixDaemonSocket
    sandboxDeniedPaths
    sandboxNetworkDomains
    sandboxReadonlyPaths
    toolRuntimePaths
    ;

  # Codex sandboxes read the whole disk by default; deny everything outside
  # the workspace except Codex's runtime set and the tool paths above.
  codexPermissions = config: {
    approval_policy = "on-request";
    approvals_reviewer = "user";
    # Domain rules are not enforced without the proxy.
    features.network_proxy = true;

    default_permissions = "workspace-only";
    permissions.workspace-only = {
      extends = ":workspace";
      network = {
        enabled = true;
        # Hosts outside the allowlist go through on-request approval. "limited"
        # would also block non-GET methods and require HTTPS MITM, neither of
        # which can be approved.
        mode = "full";
        domains = lib.genAttrs sandboxNetworkDomains (_: "allow");
        allow_local_binding = false;
        allow_upstream_proxy = false;
        # Nix builds run through the daemon, outside the agent sandbox.
        unix_sockets.${nixDaemonSocket} = "allow";
      };

      filesystem = {
        ":root" = "deny";
        ":minimal" = "read";

        ":workspace_roots" = {
          "." = "write";
          # `:workspace` keeps `.git` read-only, which blocks commits even
          # after approval. Keep hooks and config read-only: they run outside
          # the sandbox.
          ".git" = "write";
          ".git/hooks" = "read";
          ".git/config" = "read";
          "**/.env" = "deny";
          "**/.env.*" = "deny";
        }
        // lib.genAttrs secretFilePatterns (_: "deny");
      }
      // lib.genAttrs (sandboxReadonlyPaths config ++ toolRuntimePaths config) (_: "read")
      // lib.genAttrs (agentCaches config).writePaths (_: "write")
      // {
        "${config.home.homeDirectory}/.codex/skills" = "read";

        # Nix probes the socket before selecting the daemon store. The
        # network allowlist above permits connecting, not filesystem probes.
        ${nixDaemonSocket} = "read";
      };
    };
  };

  cursor = config: {
    allow =
      (lib.concatMap toCursorShell allowedCommands)
      ++ map (cmd: "Shell(${builtins.head cmd}:${commandString (builtins.tail cmd)})") exactCommands
      ++ [ "Read(**)" ]
      ++ map (domain: "WebFetch(${domain})") fetchDomains
      ++ map (name: "Mcp(${name}:*)") (mcpServers config);
    deny =
      (lib.concatMap toCursorShell deniedCommands)
      ++ [
        "Read(.env)"
        "Read(.env.*)"
        "Read(**/.env)"
        "Read(**/.env.*)"
      ]
      ++ map (path: "Read(${config.home.homeDirectory}/${path})") homeSecretPaths
      ++ map (pattern: "Read(${pattern})") secretFilePatterns;
  };

  claude = config: {
    allow =
      map (cmd: "Bash(${commandString cmd}:*)") allowedCommands
      ++ map (cmd: "Bash(${commandString cmd})") exactCommands
      ++ [ "Read(//nix/store/**)" ]
      # WebFetch allows also widen the Bash sandbox's network allowlist.
      ++ map (domain: "WebFetch(domain:${domain})") sandboxNetworkDomains
      # Projects list these in .mcp.json (`ct agents sync`).
      ++ map (name: "mcp__${name}__*") (mcpServers config);
    ask = map (cmd: "Bash(${commandString cmd}:*)") askCommands;
    deny =
      map (cmd: "Bash(${commandString cmd}:*)") deniedCommands
      ++ [
        "Read(**/.env)"
        "Read(**/.env.*)"
        "Edit(**/.env)"
        "Edit(**/.env.*)"
      ]
      ++ map (path: "Read(~/${path})") homeSecretPaths
      ++ map (pattern: "Read(${pattern})") secretFilePatterns;
  };

  # Copilot has no config file setting for tool rules or file tool paths,
  # only the `--allow-tool` / `--deny-tool` / `--add-dir` CLI flags.
  copilot = config: {
    allowTools =
      map (cmd: "shell(${commandString cmd}:*)") allowedCommands
      ++ map (cmd: "shell(${commandString cmd})") exactCommands
      ++ mcpServers config;
    # A relative write() path matches trailing components in any directory.
    # Copilot has no read() rule, so reads can't be denied this way.
    denyTools = map (cmd: "shell(${commandString cmd}:*)") deniedCommands ++ [
      "write(.env)"
      "write(.git/config)"
    ];
    # Reads there need no path prompt, like Claude's Read(//nix/store/**).
    # Edits still prompt, and the sandbox keeps the paths read-only.
    addDirs = sandboxReadonlyPaths config;
  };

  opencode = {
    bash = {
      "*" = "ask";
    }
    // toOpencodeRules "allow" allowedCommands
    // lib.genAttrs (map commandString exactCommands) (_: "allow")
    // toOpencodeRules "ask" askCommands
    // lib.genAttrs (map commandString askCommands) (_: "ask")
    // toOpencodeRules "deny" deniedCommands;
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

  # Leave routine commands to the sandbox and on-request approval policy.
  # Explicit prompt rules also prompt inside the sandbox, while allow rules
  # can authorize leaving it. Only commands needing extra review get rules.
  codexRules =
    concatMapStringsSep "\n" (toCodexRule "prompt") codexAskCommands
    + "\n"
    + concatMapStringsSep "\n" (toCodexRule "forbidden") deniedCommands
    + "\n";
}
