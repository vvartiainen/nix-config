{ userName, ... }:
{
  homebrew.casks = [
    "vicinae"
    # Keep Raycast installed during the trial: cleanup=zap would delete its data.
    "raycast"
  ];

  home-manager.users.${userName} =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      mergeConfig = import ../../home/merge-config.nix { inherit lib pkgs config; };
    in
    {
      xdg.dataFile."vicinae/scripts/eject-all-disks.sh".source =
        ../../../../dotfiles/vicinae/scripts/eject-all-disks.sh;

      # Quit Vicinae before activation so it cannot write stale values back.
      # Merge into its writable config, preserving app-managed settings.
      home.activation.vicinaeSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] (mergeConfig {
        name = "vicinae-settings";
        path = "${config.xdg.configHome}/vicinae/settings.json";
        format = "jsonc";
        settings = {
          "$schema" = "https://vicinae.com/schemas/config.json";
          close_on_focus_loss = true;
          keybinding = "vim";
          tray.enabled = false;
          # Preserves the current shortcut; also used by the quick-access terminal.
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
      });
    };
}
