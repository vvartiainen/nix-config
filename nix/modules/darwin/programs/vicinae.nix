{ userName, inputs, ... }:
{
  nix.settings = {
    extra-substituters = [ "https://vicinae.cachix.org" ];
    extra-trusted-public-keys = [ "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc=" ];
  };

  home-manager.users.${userName} = {
    imports = [ inputs.vicinae.homeManagerModules.default ];

    xdg.dataFile."vicinae/scripts/eject-all-disks.sh".source =
      ../../../../dotfiles/vicinae/scripts/eject-all-disks.sh;

    programs.vicinae = {
      enable = true;
      launchd.enable = true;
      settings = {
        "$schema" = "https://vicinae.com/schemas/config.json";
        close_on_focus_loss = true;
        keybinding = "emacs";
        providers.macos-settings.enabled = true;
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
    };
  };
}
