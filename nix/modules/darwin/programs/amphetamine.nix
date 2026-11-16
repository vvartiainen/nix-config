{
  lib,
  pkgs,
  userName,
  ...
}:
let
  powerProtect = pkgs.stdenvNoCC.mkDerivation {
    pname = "amphetamine-power-protect";
    version = "2023-12-07";

    # Upstream distributes the compiled AppleScript only inside this installer.
    src = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/x74353/Amphetamine-Power-Protect/4937590499c5504f9623dcf290c099349cf8e8fd/DMG/Power%20Protect%20for%20Amphetamine.dmg";
      sha256 = "f5627906d61f141c73743ca37c4588fc79fcf2a163ef5f8f562fb7e0e85eb2ca";
    };

    nativeBuildInputs = [
      pkgs._7zz
      pkgs.xar
      pkgs.cpio
    ];
    unpackPhase = ''
      runHook preUnpack
      7zz x "$src" -odisk -y
      xar -xf "disk/Install Power Protect.pkg" Power_Protect_for_Amphetamine.pkg/Payload
      mkdir payload
      cd payload
      gzip -dc ../Power_Protect_for_Amphetamine.pkg/Payload | cpio -idm
      runHook postUnpack
    '';
    dontBuild = true;
    dontFixup = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp "Library/Application Scripts/com.if.Amphetamine/powerProtect.scpt" "$out/"
      runHook postInstall
    '';

    meta = {
      description = "Amphetamine's closed-display Power Protect AppleScript";
      homepage = "https://github.com/x74353/Amphetamine-Power-Protect";
      license = lib.licenses.mit;
      platforms = lib.platforms.darwin;
    };
  };
in
{
  homebrew.masApps.Amphetamine = 937984704;

  # Keep upstream's exact filename: the AppleScript checks it before acting.
  # Limit the upstream %admin / ALL rule to this user, root, and two commands.
  environment.etc."sudoers.d/amphetamine_PowerProtect" = {
    text = ''
      ${userName} ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0
    '';
  };

  home-manager.users.${userName} = { lib, ... }: {
    # Copy into the sandbox's permitted Application Scripts directory rather
    # than making Amphetamine follow a symlink into the Nix store.
    home.activation.amphetaminePowerProtect = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      scripts="$HOME/Library/Application Scripts/com.if.Amphetamine"
      run mkdir -p "$scripts"
      run /usr/bin/install -m 0644 ${powerProtect}/powerProtect.scpt "$scripts/powerProtect.scpt"
    '';
  };
}
