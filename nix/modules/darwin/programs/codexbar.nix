{
  homebrew.casks = [ "codexbar" ];

  # CodexBar's native global shortcut opens the usage menu directly.
  # KeyboardShortcuts stores JSON with Carbon key/modifier codes:
  # U = 32, Cmd = 256, Ctrl = 4096.
  system.defaults.CustomUserPreferences."com.steipete.codexbar" = {
    KeyboardShortcuts_openMenu = builtins.toJSON {
      carbonKeyCode = 32;
      carbonModifiers = 4352;
    };
  };
}
