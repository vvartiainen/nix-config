{
  config,
  lib,
  userName,
  ...
}:
{
  homebrew = {
    enable = true;

    brews = [
      "ansible"
      "awscli"
      "bat"
      "btop"
      "cmake"
      "composer"
      "coreutils"
      "cpm"
      "docker"
      "duckdb"
      "fastfetch"
      "fd"
      "felixkratz/formulae/sketchybar"
      "ffmpeg"
      "ffmpegthumbnailer"
      "figlet"
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
      "pkgconf"
      "pnpm"
      "podman"
      "poppler"
      "ripgrep"
      "scc"
      "sevenzip"
      "shellcheck" # TODO: Move to nix
      "sqlite"
      "tectonic"
      "thefuck"
      "tlrc"
      "tmux"
      "unar"
      "uv"
      "wget"
      "yt-dlp"
    ];

    taps = [
      "felixkratz/formulae"
      "jesseduffield/lazydocker"
      "asmvik/formulae"
    ];

    casks = [
      "1password-cli"
      "azure-cli"
      "brave-browser"
      "chatgpt"
      "claude"
      "codex"
      "codexbar"
      "drawio"
      "android-platform-tools"
      "android-studio"
      "cursor"
      "devtoys"
      "discord"
      "font-hack-nerd-font"
      "font-jetbrains-mono-nerd-font"
      "font-sf-pro"
      "font-sketchybar-app-font"
      "font-symbols-only-nerd-font"
      "font-ubuntu-mono-nerd-font"
      "ghostty"
      "kitty"
      "localsend"
      "moonlight"
      "obsidian"
      "podman-desktop"
      "radix"
      "raycast"
      "sf-symbols"
      "slack"
      "spotify"
      "tidal"
      "visual-studio-code"
    ];

    masApps = {
      "1Password for Safari" = 1569813296;
      "Amphetamine" = 937984704;
      "Keynote" = 361285480;
      "Numbers" = 361304891;
      "Pages" = 361309726;
      "Tailscale" = 1475387142;
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

  home-manager.users.${userName} = {
    home = {
      sessionPath = [
        # libpq is not on PATH without this when installed from homebrew
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

  # The just switch skip_homebrew parameter controls this one-shot flag.
  system.activationScripts.homebrew.text = lib.mkForce ''
    skipHomebrew=0
    if [[ -f /tmp/nix-darwin-skip-homebrew ]]; then
      skipHomebrew=$(cat /tmp/nix-darwin-skip-homebrew)
      rm -f /tmp/nix-darwin-skip-homebrew
    fi
    if [[ "$skipHomebrew" == 1 ]]; then
      echo >&2 "Skipping Homebrew bundle (skip_homebrew=1)"
    else
      echo >&2 "Homebrew bundle..."
      if [ -f "${config.homebrew.prefix}/bin/brew" ]; then
        ${config.homebrew.onActivation.brewBundleCmd { onlyCheck = false; }}
      else
        echo -e "\e[1;31merror: Homebrew is not installed, skipping...\e[0m" >&2
      fi
    fi
  '';
}
