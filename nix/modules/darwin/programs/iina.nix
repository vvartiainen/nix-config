{
  lib,
  pkgs,
  userName,
  ...
}:
let
  # The .iinaplgz bundle carries a prebuilt Go helper and an LGPL ffmpeg, all
  # ad-hoc signed and not notarized. IINA runs them because it never applies
  # com.apple.quarantine when installing, and Nix adds none either, so the
  # contents must stay byte-identical: no strip, no shebang patching.
  airplayPlugin = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "iina-airplay";
    version = "0.4.2";

    src = pkgs.fetchurl {
      url = "https://github.com/ozykhan/iina-airplay/releases/download/v${finalAttrs.version}/iina-airplay.iinaplgz";
      hash = "sha256-83qR8NJ6mdEX6qcotUuTM2JlS9MlZ7gLweb6YYfeiUo=";
    };

    nativeBuildInputs = [ pkgs.unzip ];
    dontBuild = true;
    dontFixup = true;

    unpackPhase = ''
      runHook preUnpack
      unzip -q "$src" -d plugin
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -R plugin/. "$out/"
      runHook postInstall
    '';

    meta = {
      description = "IINA plugin that casts the current file to an AirPlay device";
      homepage = "https://github.com/ozykhan/iina-airplay";
      license = lib.licenses.mit;
      platforms = [ "aarch64-darwin" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  });
in
{
  # nixpkgs repacks the signed upstream release, so no cask is needed. The
  # plugin store is unused as well: activation installs the plugin below.
  environment.systemPackages = [ pkgs.iina ];

  # Sparkle cannot replace an app inside the read-only store; new versions come
  # from `just up`.
  system.defaults.CustomUserPreferences."com.colliderli.iina".SUEnableAutomaticChecks = false;

  home-manager.users.${userName} = { lib, ... }: {
    # IINA only scans its Application Support plugins directory, where installed
    # plugins are <identifier>.iinaplugin. Copy the declared release in place
    # instead of linking it, so IINA can write plugin data and the next switch
    # replaces a copy it updated itself.
    home.activation.iinaAirPlayPlugin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      plugins="$HOME/Library/Application Support/com.colliderli.iina/plugins"
      plugin="$plugins/dev.faruk.iina-airplay.iinaplugin"
      if ! /usr/bin/grep -q "\"version\": \"${airplayPlugin.version}\"" "$plugin/Info.json" 2>/dev/null; then
        run mkdir -p "$plugins"
        run rm -rf "$plugin"
        run cp -R ${lib.escapeShellArg "${airplayPlugin}/."} "$plugin"
      fi
    '';
  };
}
