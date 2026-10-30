let
  machine = "podman-machine-default";
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

  # The nixpkgs build has no podman-mac-helper for /var/run/docker.sock, so
  # point Docker clients at the machine's API socket under $TMPDIR instead.
  home.sessionVariables.DOCKER_HOST = "unix://$TMPDIR/podman/${machine}-api.sock";
}
