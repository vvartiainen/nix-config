{
  config,
  inputs,
  lib,
  ...
}:
{
  imports = [ inputs.zen-browser.homeModules.beta ];

  # Zen must be able to write profiles.ini to record its install, so a read-only store symlink
  # breaks profile selection. https://github.com/0xc000022070/zen-browser-flake/issues/285
  home.file."${config.home.homeDirectory}/Library/Application Support/Zen/profiles.ini".enable =
    lib.mkForce false;

  programs.zen-browser = {
    enable = true;

    policies.ExtensionSettings =
      builtins.mapAttrs
        (_: slug: {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/${slug}/latest.xpi";
          installation_mode = "force_installed";
        })
        {
          "uBlock0@raymondhill.net" = "ublock-origin";
          "addon@darkreader.org" = "darkreader";
          "{d634138d-c276-4fc8-924b-40a0ea21d284}" = "1password-x-password-manager";
          "idcac-pub@guus.ninja" = "istilldontcareaboutcookies";
        };

    # Reuse the profile created by the former Homebrew install.
    profiles.default = {
      id = 0;
      isDefault = true;
      path = "wam86ip4.Default (release)";

      # Ids must match the existing spaces, otherwise Zen creates new ones and their tabs are lost.
      spaces = {
        "Home" = {
          id = "d77cdafd-fcdf-4f24-970d-70ff6b99c272";
          position = 1000;
          icon = "🏠";
          container = 1;
          theme.rotation = -45;
        };
        "Programming" = {
          id = "b31e9ba1-7b63-4f6e-bf57-3f53059399ce";
          position = 2000;
          container = 1;
        };
        "Misc" = {
          id = "7c02a0c9-07da-4ce1-b94c-ea5bc827db74";
          position = 3000;
          container = 1;
        };
      };
    };
  };
}
