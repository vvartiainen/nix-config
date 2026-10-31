{
  homebrew.casks = [ "raycast" ];

  # Only the preferences plist is declarative. Command hotkeys, aliases,
  # quicklinks, snippets and extensions live in Raycast's encrypted database.
  # Quit Raycast before applying, or it may write its in-memory values back.
  system.defaults.CustomUserPreferences."com.raycast.macos" = {
    raycastGlobalHotkey = "Command-49"; # Cmd+Space
    raycastPreferredWindowMode = "compact";
    raycastShouldFollowSystemAppearance = false;
    raycastCurrentThemeId = "bundled-raycast-dark";
    raycastCurrentThemeIdDarkAppearance = "bundled-raycast-dark";
    pageNavigationCommandKeysIdentifierKey = "arrows";
    popToRootTimeout = 30; # seconds
    useHyperKeyIcon = false;
    showGettingStartedLink = false;
  };
}
