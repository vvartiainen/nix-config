{
  config,
  lib,
  userName,
  ...
}:
{
  # nix-darwin's activate script starts with `env -i`, so `just switch` writes
  # this file from SKIP_HOMEBREW.
  system.activationScripts.homebrew.text = lib.mkForce ''
    skipHomebrew=0
    if [[ -f /tmp/nix-darwin-skip-homebrew ]]; then
      skipHomebrew=$(cat /tmp/nix-darwin-skip-homebrew)
      rm -f /tmp/nix-darwin-skip-homebrew
    fi
    if [[ "$skipHomebrew" == 1 ]]; then
      echo >&2 "Skipping Homebrew bundle (SKIP_HOMEBREW=1)"
    else
      echo >&2 "Homebrew bundle..."
      if [ -f "${config.homebrew.prefix}/bin/brew" ]; then
        ${config.homebrew.onActivation.brewBundleCmd { onlyCheck = false; }}
      else
        echo -e "\e[1;31merror: Homebrew is not installed, skipping...\e[0m" >&2
      fi
    fi
  '';

  home-manager.users.${userName} = {
    home = {
      sessionPath = [
        "/opt/homebrew/opt/libpq/bin"
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
      "gh"
      "ghostscript"
      "git"
      "git-delta"
      "git-lfs"
      "gnu-sed"
      "gnumeric"
      "imagemagick"
      "jq"
      "julia"
      "just"
      "asmvik/formulae/skhd"
      # Kept as a rollback target; /opt/yabai/bin is ahead of Homebrew when the Nix fork is active.
      # Ref. ./yabai.nix
      {
        name = "asmvik/formulae/yabai";
        args = [ "HEAD" ];
      }
      "kubernetes-cli"
      "lazydocker"
      "libpq"
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
      "scc"
      "sevenzip"
      "shellcheck"
      "sqlc"
      "sqlfluff"
      "sqlite"
      "tectonic"
      "thefuck"
      "tlrc"
      "tmux"
      "tree-sitter"
      "unar"
      "uv"
      "valkey"
      "wget"
      "yt-dlp"
      "zig"
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
      "codex"
      "drawio"
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
      autoUpdate = false;
      upgrade = false;
      cleanup = "zap";
    };
  };

}
