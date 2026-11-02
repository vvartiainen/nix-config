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
      # Optional result sources turned on in System Settings → Spotlight.
      # Related content and iPhone apps are off.
      EnabledPreferenceRules = [ ];
    };

    "com.apple.symbolichotkeys".AppleSymbolicHotKeys = {
      # Show Spotlight search: Cmd+Option+Space, as Raycast has Cmd+Space.
      "64" = spaceHotkey true (cmd + option);
      # Show Finder search window: off.
      "65" = spaceHotkey false (cmd + shift);
    };
  };

  # The menu bar item lives in the per-host domain, which
  # CustomUserPreferences cannot write.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    ${asUser} defaults -currentHost write com.apple.Spotlight MenuItemHidden -bool true
    # Apply shortcut changes without logging out.
    ${asUser} /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  '';
}
