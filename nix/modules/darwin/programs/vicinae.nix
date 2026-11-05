{ userName, ... }:
{
  # The Homebrew build is properly signed, so macOS privacy permissions match
  # the running server and survive updates. The Nix build's Qt launcher breaks
  # permission checks.
  homebrew.casks = [ "vicinae" ];

  home-manager.users.${userName} =
    { pkgs, ... }:
    let
      settings = (pkgs.formats.json { }).generate "vicinae-settings.json" {
        "$schema" = "https://vicinae.com/schemas/config.json";
        close_on_focus_loss = true;
        keybinding = "emacs";
        providers.macos-settings.enabled = true;
        tray.enabled = false;
        # Cmd+Space: Qt maps "control" to Cmd on macOS.
        global_shortcuts.toggle = "control+SPACE";
        font.normal = {
          family = "JetBrainsMono Nerd Font";
          size = 13;
        };
        theme.dark.name = "catppuccin-mocha";
        telemetry.system_info = false;
        launcher_window = {
          compact_mode.enabled = true;
          material = "auto";
        };
      };
      overrides = toString settings;
    in
    {
      xdg.dataFile."vicinae/scripts/eject-all-disks.sh".source =
        ../../../../dotfiles/vicinae/scripts/eject-all-disks.sh;

      # Declared settings take precedence over the writable settings.json.
      home.sessionVariables.VICINAE_OVERRIDES = overrides;

      # Start the app bundle's CLI directly so permissions belong to Vicinae.
      launchd.agents.vicinae = {
        enable = true;
        config = {
          ProgramArguments = [
            "/Applications/Vicinae.app/Contents/MacOS/vicinae-cli"
            "server"
          ];
          EnvironmentVariables.VICINAE_OVERRIDES = overrides;
          RunAtLoad = true;
          KeepAlive = {
            Crashed = true;
            SuccessfulExit = false;
          };
          ProcessType = "Interactive";
        };
      };
    };
}
