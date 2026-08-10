{
  lib,
  userName,
  ...
}:
{
  home-manager.users.${userName} = {
    home = {
      sessionVariables = {
        GOROOT = "/opt/homebrew/opt/go/libexec";
      };

      sessionPath = [
        "/opt/homebrew/opt/libpq/bin"
        "/opt/homebrew/opt/go/libexec/bin"
      ];
    };

    # Ensure brew-managed completion functions are on fpath.
    programs.zsh.initContent = lib.mkBefore ''
      if [ -d /opt/homebrew/share/zsh/site-functions ]; then
        fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
      fi
    '';
  };

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
      "duckdb"
      "eugene1g/safehouse/agent-safehouse"
      "fastfetch"
      "fd"
      "felixkratz/formulae/sketchybar"
      "ffmpeg"
      "ffmpegthumbnailer"
      "figlet"
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
      "just"
      "asmvik/formulae/skhd"
      "asmvik/formulae/yabai"
      "kubernetes-cli"
      "lazydocker"
      "lazygit"
      "libpq"
      "libpq@16"
      "lsd"
      "luajit"
      "luarocks"
      "mas"
      "mise"
      "neovim"
      "nixfmt"
      "opencode"
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
      "yt-dlp"
      "zig"
      "zoxide"
      "zsh-autocomplete"
      "zsh-autosuggestions"
    ];

    taps = [
      "felixkratz/formulae"
      "jesseduffield/lazydocker"
      "asmvik/formulae"
      "oven-sh/bun"
    ];

    casks = [
      "1password-cli"
      "brave-browser"
      "calibre"
      "copilot-cli"
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
      "linear"
      "localsend"
      "moonlight"
      "obsidian"
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
      "Amphetamine" = 937984704;
      "Keynote" = 361285480;
      "Numbers" = 361304891;
      "Pages" = 361309726;
      "uBlock Origin Lite" = 6745342698;
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
