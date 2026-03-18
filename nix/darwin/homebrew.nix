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
      "atuin"
      "awscli"
      "bat"
      "btop"
      "cmake"
      "composer"
      "coreutils"
      "duckdb"
      "fastfetch"
      "fd"
      "felixkratz/formulae/sketchybar"
      "ffmpegthumbnailer"
      "fish"
      "fzf"
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
      "lazydocker"
      "lazygit"
      "lsd"
      "luarocks"
      "mas"
      "mise"
      "neovim"
      "nixfmt"
      "oven-sh/bun/bun"
      "pgformatter"
      "pnpm"
      "poppler"
      "ripgrep"
      "scc"
      "sevenzip"
      "shellcheck"
      "sqlfluff"
      "starship"
      "tectonic"
      "thefuck"
      "tlrc"
      "tmux"
      "tree-sitter"
      "tree-sitter-cli"
      "unar"
      "wget"
      "yazi"
      "zoxide"
      "zsh-autocomplete"
      "zsh-autosuggestions"
    ];

    taps = [
      "felixkratz/formulae"
      "hashicorp/tap"
      "koekeishiya/formulae"
      "nikitabobko/tap"
      "oven-sh/bun"
      "sqitchers/sqitch"
    ];

    casks = [
      "1password-cli"
      "cursor"
      "devtoys"
      "font-hack-nerd-font"
      "font-jetbrains-mono-nerd-font"
      "font-sf-pro"
      "font-symbols-only-nerd-font"
      "font-ubuntu-mono-nerd-font"
      "kitty"
      "sf-symbols"
      "slack"
    ];

    masApps = {
      "Amphetamine" = 937984704;
      "Keynote" = 409183694;
      "Numbers" = 409203825;
      "Pages" = 409201541;
      "Windows App" = 1295203466;
      "Xcode" = 497799835;
    };

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "none"; # Change this to 'zap' at some point to do cleanup
    };
  };
}
