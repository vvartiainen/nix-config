{
  config,
  lib,
  userName,
  ...
}:
let
  homeDir = config.users.users.${userName}.home;

  # Caches, toolchains and VM disks that can be rebuilt or downloaded again.
  timeMachineExcludedPaths = [
    "/var/lib/linux-builder"
    "${homeDir}/.cache"
    "${homeDir}/.npm"
    "${homeDir}/.rustup"
    "${homeDir}/.local/share/mise"
    "${homeDir}/.local/share/nvim"
    "${homeDir}/golang/pkg" # GOPATH from go.nix
    "${homeDir}/Library/Developer"
  ];
in
{
  # nix-darwin has no Time Machine options. The store can be rebuilt from this
  # flake, so keep its volume out of backups too. A failure only warns, so it
  # never stops activation.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    if ! /usr/bin/tmutil isexcluded /nix | /usr/bin/grep -q '^\[Excluded\]'; then
      /usr/bin/tmutil addexclusion -v /nix \
        || echo "warning: failed to exclude /nix from Time Machine" >&2
    fi

    # -p excludes the path itself, so the exclusion survives the directory
    # being deleted and recreated. Paths that don't exist yet are skipped
    # until a later activation.
    for path in ${lib.escapeShellArgs timeMachineExcludedPaths}; do
      if [[ -e "$path" ]] \
        && ! /usr/bin/tmutil isexcluded "$path" | /usr/bin/grep -q '^\[Excluded\]'; then
        /usr/bin/tmutil addexclusion -p "$path" \
          || echo "warning: failed to exclude $path from Time Machine" >&2
      fi
    done
  '';

  security.pam.services.sudo_local = {
    enable = true;
    touchIdAuth = true;
  };

  system = {
    primaryUser = userName;

    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = true;
    };

    defaults = {
      dock = {
        autohide = true;
        show-recents = false;
        static-only = true;
      };

      finder = {
        _FXShowPosixPathInTitle = true;
        AppleShowAllExtensions = false;
        FXEnableExtensionChangeWarning = false;
        QuitMenuItem = true;
        ShowPathbar = true;
        ShowStatusBar = true;
      };

      trackpad = {
        Clicking = false; # enable tap to click()
        TrackpadRightClick = true; # enable two finger right click
        TrackpadThreeFingerDrag = false; # enable three finger drag
      };

      NSGlobalDomain = {
        "com.apple.swipescrolldirection" = false;
        "com.apple.sound.beep.feedback" = 0;

        "com.apple.keyboard.fnState" = true; # enable function keys
        AppleInterfaceStyle = "Dark";
        AppleKeyboardUIMode = 3;
        ApplePressAndHoldEnabled = false;

        InitialKeyRepeat = 15; # normal minimum is 15 (225 ms), maximum is 120 (1800 ms)
        KeyRepeat = 2; # normal minimum is 2 (30 ms), maximum is 120 (1800 ms)

        NSAutomaticCapitalizationEnabled = false; # disable auto capitalization
        NSAutomaticDashSubstitutionEnabled = false; # disable auto dash substitution
        NSAutomaticPeriodSubstitutionEnabled = false; # disable auto period substitution
        NSAutomaticQuoteSubstitutionEnabled = false; # disable auto quote substitution
        NSAutomaticSpellingCorrectionEnabled = false; # disable auto spelling correction
        NSNavPanelExpandedStateForSaveMode = true; # expand save panel by default
        NSNavPanelExpandedStateForSaveMode2 = true;
        _HIHideMenuBar = true; # hide menu bar
      };

      # Customize settings that not supported by nix-darwin directly
      # see the source code of this project to get more undocumented options:
      #    https://github.com/rgcr/m-cli
      #
      # All custom entries can be found by running `defaults read` command.
      # or `defaults read xxx` to read a specific domain.
      CustomUserPreferences = {
        ".GlobalPreferences" = {
          # automatically switch to a new space when switching to the application
          AppleSpacesSwitchOnActivate = true;
        };
        NSGlobalDomain = {
          # Add a context menu item for showing the Web Inspector in web views
          WebKitDeveloperExtras = true;
        };
        "com.apple.finder" = {
          ShowExternalHardDrivesOnDesktop = false;
          ShowHardDrivesOnDesktop = false;
          ShowMountedServersOnDesktop = true;
          ShowRemovableMediaOnDesktop = true;
          _FXSortFoldersFirst = true;
          # When performing a search, search the current folder by default
          FXDefaultSearchScope = "SCcf";
        };
        "com.apple.desktopservices" = {
          # Avoid creating .DS_Store files on network or USB volumes
          DSDontWriteNetworkStores = true;
          DSDontWriteUSBStores = true;
        };
        "com.apple.screensaver" = {
          # Require password immediately after sleep or screen saver begins
          askForPassword = 1;
          askForPasswordDelay = 0;
        };
        "com.apple.screencapture" = {
          location = "~/Desktop";
          type = "png";
        };
        "com.apple.AdLib" = {
          allowApplePersonalizedAdvertising = false;
        };
        "com.apple.ImageCapture".disableHotPlug = true; # Do not open Photos when plugging in device
      };

      loginwindow = {
        GuestEnabled = false; # disable guest user
        SHOWFULLNAME = false; # show full name in login window
      };
    };
  };
}
