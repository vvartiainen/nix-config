{ pkgs, ... }:
let
  # Release binary; a source build needs CGO and a separate Node frontend
  # build.
  agentsview = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "agentsview";
    version = "0.46.1";
    src = pkgs.fetchurl {
      url = "https://github.com/kenn-io/agentsview/releases/download/v${finalAttrs.version}/agentsview_${finalAttrs.version}_darwin_arm64.tar.gz";
      hash = "sha256-g82Ycqz1v1nnfBSVBEMeMX7tdFNxaaJ/SNcy22+UFBU=";
    };
    sourceRoot = ".";
    nativeBuildInputs = [ pkgs.makeWrapper ];
    # Install the release binary unmodified.
    dontStrip = true;
    # The daemon is a detached child of the CLI and inherits these. Nix
    # handles updates, so the GitHub release check is off too.
    installPhase = ''
      install -Dm755 agentsview $out/libexec/agentsview
      makeWrapper $out/libexec/agentsview $out/bin/agentsview \
        --set AGENTSVIEW_TELEMETRY_ENABLED 0 \
        --set DO_NOT_TRACK 1 \
        --set AGENTSVIEW_DISABLE_UPDATE_CHECK 1
    '';
    meta.mainProgram = "agentsview";
  });
in
{
  home.packages = [ agentsview ];
}
