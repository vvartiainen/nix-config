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
      hitoolbox.AppleFnUsageType = "Show Emoji & Symbols";

      dock = {
        autohide = true;
        launchanim = false;
        mineffect = "scale";
        minimize-to-application = true;
        mru-spaces = false;
        show-recents = false;
        showAppExposeGestureEnabled = false;
        showLaunchpadGestureEnabled = false;
        showMissionControlGestureEnabled = true;
        static-only = true;
        tilesize = 60;
        wvous-br-corner = 14; # Quick Note
      };

      finder = {
        _FXShowPosixPathInTitle = true;
        AppleShowAllExtensions = false;
        AppleShowAllFiles = true;
        FXDefaultSearchScope = "SCcf"; # search the current folder
        FXEnableExtensionChangeWarning = false;
        FXPreferredViewStyle = "icnv";
        FXRemoveOldTrashItems = true;
        QuitMenuItem = true;
        ShowExternalHardDrivesOnDesktop = false;
        ShowHardDrivesOnDesktop = false;
        ShowMountedServersOnDesktop = true;
        ShowPathbar = true;
        ShowRemovableMediaOnDesktop = true;
        ShowStatusBar = true;
        _FXSortFoldersFirst = true;
      };

      trackpad = {
        # These values were captured for both built-in and Bluetooth trackpads.
        Clicking = false;
        Dragging = false;
        DragLock = false;
        TrackpadMomentumScroll = true;
        TrackpadPinch = true;
        TrackpadRightClick = true;
        TrackpadRotate = true;
        TrackpadThreeFingerDrag = false;
      };

      WindowManager = {
        AppWindowGroupingBehavior = true;
        AutoHide = false;
        EnableStandardClickToShowDesktop = false;
        EnableTiledWindowMargins = false;
        # Let yabai handle window positioning.
        EnableTilingByEdgeDrag = false;
        EnableTopTilingByEdgeDrag = false;
        EnableTilingOptionAccelerator = false;
        GloballyEnabled = false; # Stage Manager
        HideDesktop = true;
        StageManagerHideWidgets = true;
        StandardHideDesktopIcons = false;
        StandardHideWidgets = true;
      };

      screencapture = {
        location = "~/Desktop";
        save-selections = false;
        target = "clipboard";
        type = "png";
      };

      universalaccess.reduceMotion = false;

      ".GlobalPreferences"."com.apple.mouse.scaling" = 1.0;

      NSGlobalDomain = {
        "com.apple.swipescrolldirection" = false;
        "com.apple.sound.beep.feedback" = 0;
        "com.apple.springing.delay" = 0.5;
        "com.apple.springing.enabled" = true;
        "com.apple.trackpad.forceClick" = true;
        "com.apple.trackpad.scaling" = 0.6875;

        "com.apple.keyboard.fnState" = true; # enable function keys
        AppleInterfaceStyle = "Dark";
        AppleKeyboardUIMode = 3; # preserve current Tab/Shift-Tab keyboard navigation
        ApplePressAndHoldEnabled = false;
        # Preserve the captured global/Finder domain difference.
        AppleShowAllExtensions = true;
        AppleShowScrollBars = "Automatic";
        AppleSpacesSwitchOnActivate = true;

        InitialKeyRepeat = 15; # normal minimum is 15 (225 ms), maximum is 120 (1800 ms)
        KeyRepeat = 2; # normal minimum is 2 (30 ms), maximum is 120 (1800 ms)

        NSAutomaticCapitalizationEnabled = false; # disable auto capitalization
        NSAutomaticDashSubstitutionEnabled = false; # disable auto dash substitution
        NSAutomaticInlinePredictionEnabled = false;
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
        NSGlobalDomain = {
          # Add a context menu item for showing the Web Inspector in web views
          WebKitDeveloperExtras = true;
        };
        "com.apple.AppleMultitouchTrackpad" = {
          # nix-darwin's trackpad options write to both trackpad domains.
          # These values were captured only for the built-in trackpad.
          ActuateDetents = true;
          FirstClickThreshold = 1;
          ForceSuppressed = false;
          SecondClickThreshold = 1;
          TrackpadCornerSecondaryClick = 0;
          TrackpadFourFingerHorizSwipeGesture = 2;
          TrackpadFourFingerPinchGesture = 2;
          TrackpadFourFingerVertSwipeGesture = 2;
          TrackpadThreeFingerHorizSwipeGesture = 2;
          TrackpadThreeFingerTapGesture = 0;
          TrackpadThreeFingerVertSwipeGesture = 2;
          TrackpadTwoFingerDoubleTapGesture = false;
          TrackpadTwoFingerFromRightEdgeSwipeGesture = 3;
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
