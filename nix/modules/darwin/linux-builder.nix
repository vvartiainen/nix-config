{
  lib,
  pkgs,
  hardware,
  ...
}:
{
  # VZ builder with nested virtualization for NixOS VM tests. Everyday Linux
  # builds go to the on-demand rosetta-builder instead.
  nix.linux-builder = {
    enable = true;
    package = pkgs.darwin.linux-builder-vz;
    systems = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    ephemeral = false;
    maxJobs = 4;
    supportedFeatures = [
      "benchmark"
      "big-parallel"
    ]
    ++ lib.optionals hardware.nestedVirtualization [
      "kvm"
      "nixos-test"
    ];
    # Take only builds that need /dev/kvm. The rosetta-builder also advertises
    # kvm without having it, so win ties against its speedFactor; Nix falls
    # back to it when this builder is stopped.
    mandatoryFeatures = lib.optionals hardware.nestedVirtualization [ "kvm" ];
    speedFactor = if hardware.nestedVirtualization then 4 else 1;
    config = {
      virtualisation = {
        # Real /dev/kvm in the guest for nixos tests. Needs M3 or newer and
        # macOS 15+, otherwise the VM refuses to start (see README).
        vz.nestedVirtualization = hardware.nestedVirtualization;
        darwin-builder = {
          diskSize = 30 * 1024;
          memorySize = 8 * 1024;
        };
        cores = 6;
      };
    };
  };

  # Start the builder on demand (`just builder-start`). An always-on VM sits
  # through host sleep/wake cycles and can spin the host CPU afterwards.
  launchd.daemons.linux-builder.serviceConfig = {
    KeepAlive = lib.mkForce false;
    RunAtLoad = lib.mkForce false;
  };
}
