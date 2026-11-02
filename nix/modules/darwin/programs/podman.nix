{
  config,
  lib,
  pkgs,
  ...
}:
let
  machine = "podman-machine-default";
  podman = config.services.podman.package;
  mergeConfig = import ../../home/merge-config.nix { inherit lib pkgs config; };
in
{
  # Machine sizes apply only when activation creates the machine; recreate it
  # with `podman machine rm` to resize. Activation also removes any machine
  # not declared here.
  services.podman = {
    enable = true;
    useDefaultMachine = false;
    machines.${machine} = {
      # vCPUs are not reserved; memory is held by the VM while it runs.
      cpus = 4;
      memory = 4096;
      diskSize = 50;
      # The watchdog would restart the VM after every `podman machine stop`.
      autoStart = false;
    };
    # Pin podman 6's macOS default; applies only when the machine is created.
    settings.containers.machine.provider = "libkrun";
  };

  programs.zsh.initContent = ''
    compdef docker=podman
  '';

  home = {
    packages = [
      # Docker CLI compatibility: `docker` runs podman, like NixOS dockerCompat.
      (pkgs.runCommand "podman-docker-compat" { } ''
        mkdir -p $out/bin
        ln -s ${lib.getExe podman} $out/bin/docker
      '')
      # Provider for `podman compose` and so `docker compose`.
      pkgs.docker-compose
    ];

    # The nixpkgs build has no podman-mac-helper for /var/run/docker.sock, so
    # point Docker clients at the machine's API socket under $TMPDIR instead.
    sessionVariables.DOCKER_HOST = "unix://$TMPDIR/podman/${machine}-api.sock";

    # Podman Desktop (Homebrew cask) gets no Nix PATH when launched from the
    # Dock, so point it at the store binary. The app keeps its other settings.
    activation.podmanDesktopSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] (mergeConfig {
      name = "podman-desktop-settings";
      path = "${config.xdg.dataHome}/containers/podman-desktop/configuration/settings.json";
      settings."podman.binary.path" = lib.getExe podman;
    });
  };
}
