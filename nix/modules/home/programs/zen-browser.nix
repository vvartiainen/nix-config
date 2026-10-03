{
  config,
  inputs,
  lib,
  ...
}:
let
  profilesIni = "${config.programs.zen-browser.configPath}/profiles.ini";
in
{
  imports = [ inputs.zen-browser.homeModules.beta ];

  # Zen must be able to write profiles.ini to record its install, so the read-only store symlink
  # is replaced with a writable copy. https://github.com/0xc000022070/zen-browser-flake/issues/285
  home.file.${profilesIni}.force = true;
  home.activation.zenWritableProfilesIni = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [ -L "${profilesIni}" ]; then
      src="$(readlink "${profilesIni}")"
      run rm "${profilesIni}"
      run install -m 644 "$src" "${profilesIni}"
    fi
  '';

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

    profiles.default = {
      id = 0;
      isDefault = true;

      keyboardShortcuts =
        lib.mapAttrsToList
          (id: key: {
            inherit id key;
            modifiers = {
              control = true;
              shift = true;
              alt = false;
              meta = false;
              accel = false;
            };
          })
          {
            "zen-workspace-backward" = "h";
            "zen-workspace-forward" = "l";
          };

      # Essentials are shown in every space that shares their container.
      pins = {
        "Gmail" = {
          id = "d22202ce-2e7b-4d08-b71f-cae66dc50268";
          url = "https://mail.google.com/";
          position = 100;
          isEssential = true;
          container = 1;
        };
        "Google Calendar" = {
          id = "55ae16b2-b34e-44f2-acd1-2d5659eacee4";
          url = "https://calendar.google.com/";
          position = 200;
          isEssential = true;
          container = 1;
        };
        "Helsingin Sanomat" = {
          id = "81682fab-d725-495a-8a9b-c9012e2e1fb3";
          url = "https://www.hs.fi/";
          position = 300;
          isEssential = true;
          container = 1;
        };
      };

      # Fixed ids keep the spaces identical across machines and rebuilds.
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
