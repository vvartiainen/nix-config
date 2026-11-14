{ lib, config }:
let
  # Shared policy only; each CLI module renders its native permission format.
  # Include absolute spellings: prefix rules need not resolve symlinks or PATH.
  rexExecutables = lib.unique (
    [
      "rex"
      "${config.home.profileDirectory}/bin/rex"
      "${config.home.homeDirectory}/.nix-profile/bin/rex"
      "/etc/profiles/per-user/${config.home.username}/bin/rex"
      "/run/current-system/sw/bin/rex"
    ]
    ++ lib.optional (
      (config.programs.rex.enable or false) && (config.programs.rex.package or null) != null
    ) (lib.getExe config.programs.rex.package)
    ++
      lib.concatMap
        (app: [
          "${app}/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex"
        ])
        [
          "/Applications/Rex.app"
          "/Applications/Rex Beta.app"
          "/Applications/Nix Apps/Rex.app"
          "/Applications/Nix Apps/Rex Beta.app"
          "${config.home.homeDirectory}/Applications/Rex.app"
          "${config.home.homeDirectory}/Applications/Rex Beta.app"
        ]
  );
  # Native adapters cannot all express the same predicates. Keep argv prefixes,
  # exact invocations and whole-command patterns separate; never approximate an
  # exact allowance with a wider prefix.
  argv = map (lib.splitString " ");
  commands = {
    inherit rexExecutables;
    inspection = argv [
      "git status"
      "git diff"
      "git log"
      "git show"
      "git blame"
      "git ls-files"
      "git rev-parse"
      "git ls-tree"
      "git check-ignore"
      "git rev-list"
      "git describe"
      "nix eval"
      "nix flake show"
      "nix flake metadata"
      "nix path-info"
      "nix why-depends"
      "nix derivation show"
      "nix log"
      "gh pr view"
      "gh pr diff"
      "gh pr checks"
      "gh pr list"
      "gh issue view"
      "gh issue list"
      "gh run view"
      "gh run list"
      "fj pr view"
      "fj pr status"
      "fj pr search"
      "fj issue view"
      "fj issue search"
      "fj repo view"
      "mise ls"
      "mise current"
      "mise which"
      "mise where"
      "printf"
      "tail"
      "head"
      "wc"
      "base64"
      "ls"
      "echo"
      "pwd"
      "which"
      "date"
      "uname"
      "file"
      "stat"
      "basename"
      "dirname"
      "realpath"
      "cat"
      "diff"
      "cut"
      "tr"
      "jq"
      "grep"
      "sort"
      "uniq"
      "readlink"
      "du"
      "df"
      "type"
    ];

    exact = argv [
      "git branch --show-current"
      "git remote -v"
      "gh auth status"
    ];

    # These can execute project code or mutate files. Only auto-allow them
    # behind an OS sandbox; OpenCode must ask. Inspection tools with execution
    # flags (rg --pre, find -exec, sed e, awk system) belong here too.
    development = argv [
      "git add"
      "git commit"
      "rg"
      "fd"
      "find"
      "sed"
      "awk"
      "just"
      "just lint"
      "npm run"
      "npm test"
      "pnpm run"
      "pnpm test"
      "yarn run"
      "yarn test"
      "cargo test"
      "cargo check"
      "cargo build"
      "cargo clippy"
      "cargo fmt"
      "go test"
      "go build"
      "go vet"
      "pytest"
      "python3 -m pytest"
      "python3 -m unittest"
      "node --test"
      "statix check"
      "terraform fmt"
      "terraform validate"
      "tofu fmt"
      "tofu validate"
      "mkdir"
      "touch"
      "cp"
      "mv"
      "rm"
      "rmdir"
    ];

    # Host-side delegation, remote mutations and installation always need
    # review, even if networking or the filesystem would permit them.
    review = argv [
      "nix fmt"
      "nix build"
      "nix run"
      "nix shell"
      "nix develop"
      "nix flake check"
      "nix profile"
      "nix store"
      "nix copy"
      "nix flake update"
      "git push"
      "git fetch"
      "git pull"
      "git reset"
      "git clean"
      "git rebase"
      "npm install"
      "npm i"
      "npm add"
      "npm update"
      "npm exec"
      "npm ci"
      "npm publish"
      "npx"
      "pnpm install"
      "pnpm i"
      "pnpm update"
      "pnpm add"
      "pnpm publish"
      "pnpm dlx"
      "yarn install"
      "yarn up"
      "yarn add"
      "yarn publish"
      "yarn dlx"
      "pip"
      "pip3"
      "python3 -m pip"
      "uv pip"
      "uv tool"
      "uv sync"
      "uv add"
      "pipx"
      "cargo install"
      "cargo publish"
      "go install"
      "mise install"
      "mise use"
      "mise trust"
      "brew"
      "sudo"
      "doas"
      "darwin-rebuild"
      "just switch"
      "just bootstrap"
      "just rollback"
      "just rollback-to"
      "gh api"
      "gh auth login"
      "gh auth logout"
      "gh auth refresh"
      "gh auth setup-git"
      "gh auth switch"
      "gh pr create"
      "gh pr merge"
      "gh pr close"
      "gh pr edit"
      "gh pr comment"
      "gh pr review"
      "gh issue create"
      "gh issue edit"
      "gh issue close"
      "gh issue comment"
      "gh release"
      "gh run cancel"
      "gh run rerun"
      "gh workflow run"
      "fj auth"
      "fj pr create"
      "fj pr merge"
      "fj pr close"
      "fj pr edit"
      "fj pr comment"
      "fj pr review"
      "fj issue create"
      "fj issue edit"
      "fj issue close"
      "fj issue comment"
      "fj repo create"
      "fj repo delete"
      "fj repo edit"
      "fj release"
      "terraform apply"
      "terraform destroy"
      "tofu apply"
      "tofu destroy"
      "ssh"
      "scp"
      "rsync"
      "osascript"
      "open"
    ];

    # Listing metadata is distinct from capturing a terminal's contents or
    # dumping a VM's configuration, which can disclose secrets.
    hostInspection = argv [
      "rex ls"
      "rex whoami"
      "rex window ls"
      "rex block ls"
      "rex client ls"
      "incus list"
      "incus project list"
      "incus remote list"
    ];
    hostExact =
      lib.concatMap
        (exe: [
          [
            exe
            "--help"
          ]
          [
            exe
            "--version"
          ]
        ])
        [
          "rex"
          "kitty"
          "kitten"
          "incus"
        ]
      ++ [
        [
          "rex"
          "__internal"
          "skill"
          "--feature-session-naming=false"
        ]
      ];
    hostExecutables = lib.unique (
      rexExecutables
      ++
        lib.concatMap
          (exe: [
            exe
            "${config.home.profileDirectory}/bin/${exe}"
            "${config.home.homeDirectory}/.nix-profile/bin/${exe}"
            "/etc/profiles/per-user/${config.home.username}/bin/${exe}"
            "/run/current-system/sw/bin/${exe}"
            "/opt/homebrew/bin/${exe}"
          ])
          [
            "kitty"
            "kitten"
            "incus"
          ]
      ++ [
        "/Applications/kitty.app/Contents/MacOS/kitty"
        "/Applications/kitty.app/Contents/MacOS/kitten"
      ]
    );

    # Prefix blocks are accident prevention, not a shell security boundary.
    # Flag reordering needs patterns in clients that support them; other forms
    # still ask or stay sandboxed. Never turn these into broad runner grants.
    denied = argv [
      "op read"
      "op item get"
      "op document get"
      "op run"
      "op inject"
      "op plugin run"
      "security find-generic-password"
      "security find-internet-password"
      "security dump-keychain"
      "security export"
      "gh auth token"
      "gh auth status --show-token"
      "git push --force"
      "git push --force-with-lease"
      "git push -f"
      "git reset --hard"
      "git clean -f"
      "git clean -fd"
      "git clean -df"
      "git clean -fdx"
      "git clean -xdf"
      "diskutil eraseDisk"
      "diskutil eraseVolume"
      "diskutil partitionDisk"
      "diskutil zeroDisk"
      "diskutil secureErase"
      "diskutil apfs deleteContainer"
      "diskutil apfs deleteVolume"
      "rm -rf /"
      "rm -fr /"
      "newfs_apfs"
      "newfs_hfs"
      "mkfs"
    ];
    deniedPatterns = [
      "gh auth status *--show-token*"
      "git push *--force*"
      "git push * -f"
      "git push * -f *"
      "git reset *--hard*"
      "git clean *-f*"
      "git clean *-df*"
      "git clean *-xdf*"
      "rm -rf /"
      "rm -fr /"
      "rm -rf ~"
      "rm -fr ~"
      "dd *of=/dev/*"
    ];
  };

  paths = {
    # Home paths sandboxed commands may read, relative to the home directory.
    # The rest of the home directory is denied apart from the workspace;
    # reading it needs an approved command outside the sandbox.
    homeReadable = [
      # Shared skills and installed native marketplace skill helpers.
      ".agents"
      ".claude/plugins/cache"
      ".codex/plugins/cache"
      # Codex's managed worktrees, for inspecting them from other agents.
      # Removing one still writes the main repository's Git metadata.
      ".codex/worktrees"
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
      # ~/.npmrc is not listed: it links to the tracked dotfiles/.npmrc, and
      # Claude denies a link's target, which would block flake evaluation.
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
      ".config/github-copilot/**"
      ".claude/.credentials.json"
      ".gemini/oauth_creds.json"
      # T3 Code's service environment, sign-in cache, provider server registry
      # and thread database. Its cache, attachments, browser artifacts and
      # worktrees stay readable as shared host paths below.
      ".t3/service.env"
      ".t3/userdata/secrets/**"
      ".t3/userdata/clerk/**"
      ".t3/userdata/opencode-servers/**"
      ".t3/userdata/statev2.sqlite*"
      ".kube/**"
      ".config/gcloud/**"
      ".git-credentials"
      ".config/git/credentials"
      ".config/sops/**"
      ".config/age/**"
      ".password-store/**"
      ".vault-token"
      ".pypirc"
      ".gem/credentials"
      ".terraformrc"
      ".config/rclone/**"
      # Shell history often holds pasted tokens.
      ".zsh_history"
      ".bash_history"
      # Keychains and browser sessions.
      "Library/Keychains/**"
      "Library/Cookies/**"
      "Library/Application Support/Google/Chrome/**"
      "Library/Application Support/Firefox/**"
      "Library/Application Support/BraveSoftware/**"
    ];

    workspaceSecrets = [ "**/.env" "**/.env.*" ] ++ paths.secretFiles;

    secretFiles = [
      "**/*.pem"
      "**/*.key"
    ];

    # homeSecrets as plain paths, for sandboxes that don't take globs.
    denied = map (
      path: "${config.home.homeDirectory}/${lib.removeSuffix "/**" path}"
    ) paths.homeSecrets;

    # homeReadable as absolute paths, plus state an agent host app shares.
    readable =
      map (path: "${config.home.homeDirectory}/${path}") paths.homeReadable ++ paths.hostShared;

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

      # PATH entries reach Nix tools through these profile symlinks. Current
      # Home Manager releases link the profile under XDG state, and /run is a
      # symlink to /private/var/run, so both spellings need a grant.
      "${config.home.homeDirectory}/.nix-profile"
      "${config.xdg.stateHome}/nix/profiles"
      "/etc/profiles/per-user/${config.home.username}"
      "/run/current-system"
      "/private/var/run/current-system"
      "/nix/var/nix/profiles"
      "/etc/nix"
    ];

    # Read-only paths an agent host app shares with the CLI it runs. T3 Code
    # injects Pi's extension from its cache, hands attachment and browser
    # artifact paths to the model, and creates thread worktrees in its own
    # root. Everything else under its home stays in homeSecrets.
    hostShared = [
      "${config.home.homeDirectory}/.t3/caches"
      "${config.home.homeDirectory}/.t3/userdata/attachments"
      "${config.home.homeDirectory}/.t3/userdata/browser-artifacts"
      "${config.home.homeDirectory}/.t3/worktrees"
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
      "opentofu.org"
      "search.opentofu.org"
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
        HOMEBREW_CACHE = dir "homebrew";
        # Sandboxed nvim can't open its server socket or its log in
        # ~/.local/state, so it logs the failure to ./nvim.log instead.
        NVIM_LOG_FILE = "/dev/null";
        # Sandboxes block trustd, which Go uses to verify TLS on macOS.
        # Nixpkgs' Go reads this bundle instead, so Go module and toolchain
        # downloads work inside the sandboxes.
        SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
        # Skip Terraform's version check, an unlisted host.
        CHECKPOINT_DISABLE = "1";
      };
      writePaths = map dir [
        "nix"
        "cargo"
        "go"
        "mise"
        "npm"
        "homebrew"
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
