{ lib, userName, ... }:
let
  # Modifier masks for symbolic hotkey parameters.
  cmd = 1048576;
  option = 524288;
  shift = 131072;

  # Parameters are the character code, virtual key code and modifier mask;
  # 32 and 49 are Space.
  spaceHotkey =
    enabled: modifiers:
    {
      inherit enabled;
      value = {
        type = "standard";
        parameters = [
          32
          49
          modifiers
        ];
      };
    };

  asUser = ''/bin/launchctl asuser "$(id -u -- ${userName})" sudo --user=${userName} --'';
in
{
  system.defaults.CustomUserPreferences = {
    "com.apple.Spotlight" = {
      PasteboardHistoryEnabled = true; # clipboard history
      # Result categories turned off in System Settings → Spotlight.
      DisabledUTTypes = [ ];
      # Enabled exclusion rules: keep related content, files, folders,
      # iPhone apps and menu items out of results.
      EnabledPreferenceRules = [
        "Custom.relatedContents"
        "System.files"
        "System.folders"
        "System.iphoneApps"
        "System.menuItems"
      ];
    };

    "com.apple.symbolichotkeys".AppleSymbolicHotKeys = {
      # Show Spotlight search: Cmd+Option+Space.
      "64" = spaceHotkey true (cmd + option);
      # Show Finder search window: off.
      "65" = spaceHotkey false (cmd + shift);
    };
  };

  system.activationScripts.postActivation.text = lib.mkAfter ''
    # mdutil controls whole volumes, not folders. Only target /nix when it is
    # mounted separately so a plain directory cannot disable the Data index.
    if /sbin/mount | /usr/bin/grep -q ' on /nix ('; then
      # Standard Nix volumes may report "unknown indexing state" (-400).
      # Only change a volume Spotlight explicitly reports as indexing.
      if LC_ALL=C /usr/bin/mdutil -s /nix 2>/dev/null \
        | /usr/bin/grep -Fq 'Indexing enabled.'; then
        /usr/bin/mdutil -i off /nix \
          || echo "warning: failed to disable Spotlight indexing for /nix" >&2
      fi
    fi

    # The menu bar item lives in the per-host domain, which
    # CustomUserPreferences cannot write.
    ${asUser} defaults -currentHost write com.apple.Spotlight MenuItemHidden -bool true
    # Apply shortcut changes without logging out.
    ${asUser} /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  '';
}
