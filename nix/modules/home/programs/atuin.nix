{ pkgs, ... }:
let
  # Use the upstream release binary instead of pkgs.atuin. nixpkgs atuin
  # bumps often land before Hydra has a darwin build cached, which means a
  # long source build that has failed for us. Homebrew already migrated the
  # history DB, so keep this at or above the version Homebrew last ran.
  atuinVersion = "18.23.0";

  system = pkgs.stdenv.hostPlatform.system;
  releaseAssets = {
    aarch64-darwin = {
      url = "https://github.com/atuinsh/atuin/releases/download/v${atuinVersion}/atuin-aarch64-apple-darwin.tar.gz";
      hash = "sha256-gp2BsqiI8TQxzDdSLGq62so4HQaapdA7VFIfNVzn5b0=";
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
    package = atuinBinary;
  };
}
