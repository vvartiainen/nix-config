{ lib, pkgs }:
let
  version = "38.0.0";
  # Digests published with the immutable v38.0.0 release:
  # https://github.com/dyoshikawa/rulesync/releases
  assets = {
    aarch64-darwin = {
      name = "rulesync-darwin-arm64";
      sha256 = "a81ed451f9f64c83ec692e508fd0011994ca6abadd1981be2d05fbce59c371d6";
    };
    x86_64-darwin = {
      name = "rulesync-darwin-x64";
      sha256 = "4140cb6c3280e6b0aaccd85168fea5fa0a9ffaad007ebcafb89cec5f5111b2df";
    };
  };
  asset = assets.${pkgs.stdenv.hostPlatform.system};
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "rulesync";
  inherit version;
  src = pkgs.fetchurl {
    url = "https://github.com/dyoshikawa/rulesync/releases/download/v${version}/${asset.name}";
    inherit (asset) sha256;
  };
  dontUnpack = true;
  # Preserve the signature and embedded Bun executable.
  dontFixup = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/rulesync"
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    "$out/bin/rulesync" --version | grep -F '${version}'
  '';
  meta = {
    description = "Generate native agent configuration from shared inputs";
    homepage = "https://rulesync.dyoshikawa.com";
    license = lib.licenses.mit;
    platforms = builtins.attrNames assets;
    mainProgram = "rulesync";
  };
}
