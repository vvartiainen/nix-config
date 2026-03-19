{ ... }:
{
  environment = {
    variables = {
      HOMEBREW_PREFIX = "/opt/homebrew";
      HOMEBREW_CELLAR = "/opt/homebrew/Cellar";
      HOMEBREW_REPOSITORY = "/opt/homebrew";
    };

    systemPath = [
      "/opt/homebrew/bin"
      "/opt/homebrew/sbin"
    ];
  };

  homebrew = {
    enable = true;

    brews = [
      "ansible"
      "atuin"
      "awscli"
      "azure-cli"
      "bat"
      "btop"
      "cmake"
      "cocoapods"
      "composer"
      "coreutils"
      "cpm"
      "delve"
      "docker"
      "docker-completion"
      "duckdb"
      "fastfetch"
      "fd"
      "felixkratz/formulae/sketchybar"
      "ffmpeg"
      "ffmpegthumbnailer"
      "fish"
      "fzf"
      "gh"
      "ghostscript"
      "git"
      "git-delta"
      "git-lfs"
      "gnu-sed"
      "gnumeric"
      "go"
      "imagemagick"
      "jq"
      "julia"
      "koekeishiya/formulae/skhd"
      "koekeishiya/formulae/yabai"
      "kubernetes-cli"
      "lazydocker"
      "lazygit"
      "libpq"
      "lsd"
      "luajit"
      "luarocks"
      "mas"
      "mise"
      "neovim"
      "nixfmt"
      "oven-sh/bun/bun"
      "pgformatter"
      "pkgconf"
      "pnpm"
      "podman"
      "poppler"
      "ripgrep"
      "rustup"
      "scc"
      "sevenzip"
      "shellcheck"
      "sqlc"
      "sqlfluff"
      "sqlite"
      "starship"
      "tectonic"
      "thefuck"
      "tlrc"
      "tmux"
      "tree-sitter"
      "tree-sitter-cli"
      "unar"
      "uv"
      "valkey"
      "wget"
      "yazi"
      "zig"
      "zoxide"
      "zsh-autocomplete"
      "zsh-autosuggestions"
      "railwaycat/emacsmacport/emacs-mac@29"
    ];

    taps = [
      "felixkratz/formulae"
      "hashicorp/tap"
      "jesseduffield/lazydocker"
      "koekeishiya/formulae"
      "nikitabobko/tap"
      "oven-sh/bun"
      "railwaycat/emacsmacport"
      "sqitchers/sqitch"
    ];

    casks = [
      "1password-cli"
      "brave-browser"
      "calibre"
      "cursor-cli"
      "android-platform-tools"
      "android-studio"
      "cursor"
      "devtoys"
      "discord"
      "font-hack-nerd-font"
      "font-jetbrains-mono-nerd-font"
      "font-sf-pro"
      "font-symbols-only-nerd-font"
      "font-ubuntu-mono-nerd-font"
      "ghostty"
      "github"
      "kitty"
      "linear-linear"
      "moonlight"
      "podman-desktop"
      "raycast"
      "sf-symbols"
      "slack"
      "spotify"
      "tidal"
      "visual-studio-code"
      "zed"
      "zen"
    ];

    masApps = {
      "1Password for Safari" = 1569813296;
      "AdGuard for Safari" = 1440147259;
      "Amphetamine" = 937984704;
      "iMovie" = 408981434;
      "Keynote" = 409183694;
      "Numbers" = 409203825;
      "Pages" = 409201541;
      "WhatsApp" = 310633997;
      "Windows App" = 1295203466;
      "Xcode" = 497799835;
    };

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };
  };
}
