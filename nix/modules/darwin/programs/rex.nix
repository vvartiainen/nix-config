{ pkgs, ... }:
let
  rexApp = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "rex-app";
    version = "0.1.0-1696";

    # Pin the signed GUI release from Rex's official preview appcast.
    # https://blob.superlogical.com/public/rex-app/preview/appcast.xml
    src = pkgs.fetchurl {
      url = "https://blob.superlogical.com/public/rex-app/preview/Rex-${finalAttrs.version}.dmg";
      sha256 = "b192116cfe93fc8f9cf23b4ab0b77ad037c952a2bdd9a4ecff1882db426bbf8f";
    };

    nativeBuildInputs = [ pkgs.undmg ];
    sourceRoot = ".";
    dontBuild = true;
    # Preserve the vendor signatures on the app, frameworks and bundled server.
    dontFixup = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/Applications"
      cp -R "Rex Beta.app" "$out/Applications/"
      runHook postInstall
    '';

    meta = {
      description = "Rex terminal and multiplexer for macOS";
      homepage = "https://www.superlogical.com/rex";
      license = pkgs.lib.licenses.unfree;
      platforms = [ "aarch64-darwin" ];
      sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
    };
  });
in
{
  environment.systemPackages = [ rexApp ];

  # GUI preferences are separate from the server's init.lua configuration.
  # Match Kitty: keep left Option for composing characters, right Option for Alt.
  system.defaults.CustomUserPreferences."com.superlogical.rex" = {
    "Workspace.appearance" = "dark";
    "Workspace.tabStyle" = "vertical";
    "Workspace.sidebarPosition" = "left";
    "Workspace.sidebarCollapsed" = false;
    "Workspace.terminalOptionKeyBehavior" = "rightActsAsAlt";
  };
}
