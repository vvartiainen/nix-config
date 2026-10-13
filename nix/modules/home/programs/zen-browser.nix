{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  profilesIni = "${config.programs.zen-browser.configPath}/profiles.ini";
  extensionSettings = "${config.programs.zen-browser.profilesPath}/${config.programs.zen-browser.profiles.default.path}/extension-settings.json";

  # Policies cannot set extension shortcuts. "MacCtrl" is the Control key; "Ctrl" means Cmd on macOS.
  extensionShortcuts = {
    "addon@darkreader.org".addSite = "MacCtrl+Shift+D";
  };
in
{
  # Work-specific containers, essentials and spaces are kept in a gitignored file. It is only
  # visible to builds using the `path:.` flake ref from the justfile.
  imports = [
    inputs.zen-browser.homeModules.beta
  ]
  ++ lib.optional (builtins.pathExists ./zen-browser.local.nix) ./zen-browser.local.nix;

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

    # Zen rewrites extension-settings.json from memory, so this is skipped while it is running.
    activationFragments.default = [
      {
        requiresLock = true;
        skipSubject = "extension shortcuts";
        text = ''
          file="${extensionSettings}"
          if [ -d "$(dirname "$file")" ]; then
            tmp="$(mktemp)"
            { [ -f "$file" ] && cat "$file" || echo '{"version":3}'; } \
              | ${lib.getExe pkgs.jq} --argjson shortcuts ${lib.escapeShellArg (builtins.toJSON extensionShortcuts)} '
                  reduce ($shortcuts | to_entries[]) as $ext (.;
                    reduce ($ext.value | to_entries[]) as $cmd (.;
                      .commands[$cmd.key] = {
                        precedenceList: [{
                          id: $ext.key,
                          installDate: 0,
                          value: { shortcut: $cmd.value },
                          enabled: true
                        }]
                      }))' > "$tmp"
            run install -m 644 "$tmp" "$file"
            rm -f "$tmp"
          fi
        '';
      }
    ];

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
          "{d7742d87-e61d-4b78-b8a1-b469842139fa}" = "vimium-ff";
        };

    profiles.default = {
      id = 0;
      isDefault = true;

      settings = {
        "browser.ctrlTab.sortByRecentlyUsed" = false;
        "browser.translations.automaticallyPopup" = false;
      };

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

      containersForce = true;
      containers = {
        "Personal" = {
          id = 1;
          color = "turquoise";
          icon = "fingerprint";
        };
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
        "YouTube" = {
          id = "fdbc014e-984a-49b3-9571-3214eea36c7c";
          url = "https://www.youtube.com/";
          position = 400;
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
