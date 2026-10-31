{
  lib,
  stdenv,
  fetchurl,
  zig_0_16,
  apple-sdk,
  writeShellScriptBin,
  versionCheckHook,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "skhd-zig";
  version = "0.2.0";

  src = fetchurl {
    url = "https://github.com/jackielii/skhd.zig/archive/refs/tags/v${finalAttrs.version}.tar.gz";
    hash = "sha256-3yZnlGmeaz38mJdo6rZLoRXlooumd5WSzjqk8gK4gV4=";
  };

  # Reset visual mode state on startup/reload without a launchd shell wrapper.
  patches = [ ./skhd-default-mode.patch ];

  zigDeps = zig_0_16.fetchDeps {
    inherit (finalAttrs) pname version src;
    hash = "sha256-7xU/H+Sdo/ir4nCFxddKpDB5ADGvcJhJTiugYno1NYo=";
  };

  nativeBuildInputs = [
    zig_0_16.hook
    (writeShellScriptBin "xcrun" ''
      echo "${apple-sdk.sdkroot}"
    '')
  ];

  postConfigure = ''
    cp -rL ${finalAttrs.zigDeps} "$ZIG_GLOBAL_CACHE_DIR/p"
    chmod -R u+w "$ZIG_GLOBAL_CACHE_DIR/p"
  '';

  postInstall = ''
    bash scripts/make-app.sh "$out/bin/skhd" "$out/Applications/skhd.app"
  '';

  doCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "Simple hotkey daemon for macOS, ported to Zig";
    homepage = "https://github.com/jackielii/skhd.zig";
    license = lib.licenses.mit;
    mainProgram = "skhd";
    platforms = lib.platforms.darwin;
  };
})
