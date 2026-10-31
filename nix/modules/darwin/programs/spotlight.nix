{ lib, userName, ... }:
let
  # Modifier masks for symbolic hotkey parameters.
  cmd = 1048576;
  option = 524288;
  shift = 131072;

  # Shortcut ids in com.apple.symbolichotkeys. Parameters are the character
  # code, the virtual key code and the modifier mask; 32 and 49 are Space.
  spaceHotkey =
    id: enabled: modifiers:
    "defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add ${toString id} "
    + "'<dict><key>enabled</key><${lib.boolToString enabled}/><key>value</key><dict>"
    + "<key>type</key><string>standard</string><key>parameters</key><array>"
    + "<integer>32</integer><integer>49</integer><integer>${toString modifiers}</integer>"
    + "</array></dict></dict>'";

  asUser = ''/bin/launchctl asuser "$(id -u -- ${userName})" sudo --user=${userName} --'';
in
{
  system.defaults.CustomUserPreferences."com.apple.Spotlight" = {
    PasteboardHistoryEnabled = true; # clipboard history
    # Result categories turned off in System Settings → Spotlight.
    DisabledUTTypes = [ ];
    # Optional result sources turned on in System Settings → Spotlight.
    # Related content and iPhone apps are off.
    EnabledPreferenceRules = [ ];
  };

  # CustomUserPreferences rewrites a whole top-level key, which would replace
  # every other shortcut in AppleSymbolicHotKeys, so merge entries instead.
  # The menu bar item lives in the per-host domain, which it cannot write.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    # Show Spotlight search: Cmd+Option+Space, as Raycast has Cmd+Space.
    ${asUser} ${spaceHotkey 64 true (cmd + option)}
    # Show Finder search window: off.
    ${asUser} ${spaceHotkey 65 false (cmd + shift)}
    ${asUser} defaults -currentHost write com.apple.Spotlight MenuItemHidden -bool true
    # Apply shortcut changes without logging out.
    ${asUser} /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  '';
}
