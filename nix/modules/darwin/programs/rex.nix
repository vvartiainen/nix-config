{ pkgs, ... }:
let
  rexApp = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "rex-app";
    version = "0.1.0-1758";

    # Pin the signed GUI release from Rex's official preview appcast.
    # https://blob.superlogical.com/public/rex-app/preview/appcast.xml
    src = pkgs.fetchurl {
      url = "https://blob.superlogical.com/public/rex-app/preview/Rex-${finalAttrs.version}.dmg";
      sha256 = "179c2c5707422f676360a2ebb264fd8189ef5e9ca9895140863451ec7ddb3d29";
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
    "Workspace.animationStyle" = "off";
    "Workspace.appIconVisibility" = "dockOnly";
    "Workspace.tabStyle" = "vertical";
    "Workspace.tabIconTintMode" = "off";
    "Workspace.sidebarPosition" = "left";
    "Workspace.sidebarCollapsed" = false;
    "Workspace.inactivePaneFadeMode" = "both";
    "Workspace.usesStandardInactiveWindowPaneStyles" = true;
    "Workspace.cursorShadersEnabled" = true;
    "Workspace.terminalCursorStyle" = "bar";
    "Workspace.terminalFontName" = "JetBrainsMono Nerd Font Mono";
    "Workspace.terminalOptionKeyBehavior" = "rightActsAsAlt";
    # Native macOS notifications for program activity (agents waiting or
    # finished) and OSC 9/777. macOS still asks once for permission.
    "Workspace.showsProgramActivityNotifications" = true;
    "Workspace.allowsTerminalNotifications" = true;
    "Workspace.notificationPosition" = "top-right";

    "rex.agents.names-sessions" = false;
    "rex.developer-mode-enabled" = true;
    "rex.server.automatic-restart-enabled" = true;
    "rex.server.block-plugin-reload-enabled" = false;
    "rex.server.run-mode" = "bundled";
    "rex.server.web-client-origin-patterns" = [ "https://rex.superlogical.com" ];
  };
}
