{ lib, config }:
let
  # Shared policy only; each CLI module renders its native permission format.
  commands = {
    # Canonical command prefixes allowed without prompting. Each entry is argv.
    allowed = [
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
    exact = [
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

    # Daemon-backed Nix commands build outside the agent sandbox, so they
    # still need review inside it. `nix fmt` can build the flake's formatter.
    sandboxAsk = [
      [
        "nix"
        "fmt"
      ]
      [
        "nix"
        "build"
      ]
    ];

    # Project-code runners and wrappers. The sandboxed CLIs run them without
    # prompts; OpenCode has no sandbox, so it asks.
    routine = [
      [ "just" ]
      [
        "npm"
        "run"
      ]
      [ "npx" ]
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
    denied = [
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
  };

  paths = {
    # Home paths sandboxed commands may read, relative to the home directory.
    # The rest of the home directory is denied apart from the workspace;
    # reading it needs an approved command outside the sandbox.
    homeReadable = [
      ".config"
      ".local/share"
      ".local/state"
      ".cache"
      # Home Manager links and shell startup files.
      ".gitconfig"
      ".zshenv"
      ".zprofile"
      ".zshrc"
      ".bunfig.toml"
      ".yarnrc.yml"
      ".rgignore"
      ".tmux.conf"
      ".nix-profile"
      ".nix-defexpr"
      # Toolchains.
      ".cargo"
      ".rustup"
      "go"
      "golang"
      "bin"
    ];

    # Credential files denied for reads, relative to the home directory. The
    # narrower path wins, so these stay denied inside homeReadable.
    homeSecrets = [
      ".ssh/**"
      ".aws/**"
      ".azure/**"
      ".gnupg/**"
      ".docker/**"
      ".android/**"
      ".amplify/**"
      ".snowsql/**"
      ".terraform.d/**"
      ".netrc"
      ".npmrc"
      ".yarnrc"
      ".pgpass"
      ".zsh_local"
      ".emulator_console_auth_token"
      ".cargo/credentials.toml"
      ".codex/auth.json"
      ".config/op/**"
      ".config/gh/**"
      ".config/1Password/**"
      ".config/agent-proxy/**"
      ".config/codexbar/**"
      ".config/containers/**"
      ".config/raycast/**"
      ".config/anthropic/**"
      ".config/nix-config-host/**"
      ".config/cursor/mcp.json"
      ".config/opencode/opencode.json"
      ".local/share/atuin/**"
      ".local/share/containers/**"
      ".local/share/opencode/**"
      ".local/state/agent-proxy/**"
      ".local/state/agent-sandbox/**"
      ".local/state/gh/**"
      ".local/state/opencode/**"
      ".local/state/.copilot/**"
    ];

    secretFiles = [
      "**/*.pem"
      "**/*.key"
    ];

    # homeSecrets as plain paths, for sandboxes that don't take globs.
    denied = map (
      path: "${config.home.homeDirectory}/${lib.removeSuffix "/**" path}"
    ) paths.homeSecrets;

    # homeReadable as absolute paths.
    readable = map (path: "${config.home.homeDirectory}/${path}") paths.homeReadable;

    readonly = [
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
    runtime = [
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

    # Shared scratch space, writable in every sandbox so agents can use
    # literal temp paths. /tmp links to /private/tmp; sandboxes may match
    # either spelling.
    tmp = [
      "/tmp"
      "/private/tmp"
    ];

    nixDaemonSocket = "/nix/var/nix/daemon-socket/socket";
  };

  network = {
    # Domains the agents may fetch pages from.
    fetch = [
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
    sandbox = [
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
  };

  # Sandboxed package managers get their own writable caches. Unsandboxed
  # builds trust the user's normal caches, so writes there would escape the
  # sandbox.
  caches =
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
        # Sandboxed nvim can't open its server socket or its log in
        # ~/.local/state, so it logs the failure to ./nvim.log instead.
        NVIM_LOG_FILE = "/dev/null";
      };
      writePaths = map dir [
        "nix"
        "cargo"
        "go"
        "mise"
        "npm"
      ];
    };

  # Catalog tools are allowed where a project enables their MCP server.
  mcpServers = lib.attrNames config.agents.mcpServers;
in
{
  inherit
    commands
    paths
    network
    caches
    mcpServers
    ;
}
