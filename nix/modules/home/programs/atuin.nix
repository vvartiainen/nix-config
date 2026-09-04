{ pkgs, lib, ... }:
let
  # Homebrew already migrated the history DB with 18.21.0. nixpkgs is still
  # on 18.19.0 (and rustc 1.97, while 18.21.0 needs 1.98), so a source bump
  # does not build. Use the upstream release binary until pkgs.atuin is at
  # least 18.21.0.
  atuinVersion = "18.21.0";

  system = pkgs.stdenv.hostPlatform.system;
  releaseAssets = {
    aarch64-darwin = {
      url = "https://github.com/atuinsh/atuin/releases/download/v${atuinVersion}/atuin-aarch64-apple-darwin.tar.gz";
      hash = "sha256-xQ3wBef3MPULFTSNlzhQd5yU7g5A8BohIPBc+Zys6N4=";
    };
  };
  release =
    releaseAssets.${system} or (throw "No pinned atuin ${atuinVersion} binary for ${system}");

  atuinBinary = pkgs.stdenvNoCC.mkDerivation {
    pname = "atuin";
    version = atuinVersion;
    src = pkgs.fetchzip {
      inherit (release) url hash;
    };
    nativeBuildInputs = [ pkgs.installShellFiles ];
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      install -Dm755 atuin $out/bin/atuin
      installShellCompletion --cmd atuin \
        --bash <($out/bin/atuin gen-completions -s bash) \
        --fish <($out/bin/atuin gen-completions -s fish) \
        --zsh <($out/bin/atuin gen-completions -s zsh)
      runHook postInstall
    '';
    meta = {
      mainProgram = "atuin";
    };
  };
in
{
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    package =
      if lib.versionAtLeast pkgs.atuin.version atuinVersion then pkgs.atuin else atuinBinary;
  };
}
