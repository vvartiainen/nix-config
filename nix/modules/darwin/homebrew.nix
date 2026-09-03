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

  system.activationScripts.postActivation.text = lib.mkAfter ''
    yabaiBin="/opt/homebrew/bin/yabai"
    sudoersDir="/private/etc/sudoers.d"
    sudoersFile="$sudoersDir/yabai"

    if [[ ! -x "$yabaiBin" ]]; then
      echo "error: yabai binary not found at $yabaiBin" >&2
      exit 1
    fi

    yabaiHash=$(shasum -a 256 "$yabaiBin" | cut -d " " -f 1)
    mkdir -p "$sudoersDir"
    sudoersTemp=$(mktemp "$sudoersDir/.yabai.XXXXXX")
    trap 'rm -f "$sudoersTemp"' EXIT

    printf '%s ALL=(root) NOPASSWD: sha256:%s %s --load-sa\n' \
      "${userName}" "$yabaiHash" "$yabaiBin" > "$sudoersTemp"
    chmod 0440 "$sudoersTemp"
    chown root:wheel "$sudoersTemp"
    /usr/sbin/visudo -cf "$sudoersTemp" > /dev/null
    mv -f "$sudoersTemp" "$sudoersFile"

    trap - EXIT
  '';

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
      "go"
      "imagemagick"
      "jq"
      "julia"
      "just"
      "asmvik/formulae/skhd"
      {
        name = "asmvik/formulae/yabai";
        args = [ "HEAD" ];
        postinstall = "codesign -fs 'yabai-cert' $(brew --prefix yabai)/bin/yabai";
      }
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
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };
  };

}
