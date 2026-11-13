{ inputs, ... }:
{
  imports = [ inputs.nix-rosetta-builder.darwinModules.default ];

  # Lima VM for aarch64-linux and x86_64-linux (Rosetta) builds without
  # nested virtualization. A build starts it through its launchd socket and it
  # powers off after onDemandLingerMinutes idle. Changing the VM settings
  # recreates the VM. To uninstall, set enable = false and switch before
  # dropping the import: only that removes its user and /var/lib/rosetta-builder.
  nix-rosetta-builder = {
    onDemand = true;
    onDemandLingerMinutes = 30;
    # Held only while the VM runs; cores also sets maxJobs.
    cores = 10;
    memory = "16GiB";
    diskSize = "50GiB";
    # Preferred over a linux-builder without nested virtualization (1), below
    # one with it (4) for kvm builds.
    speedFactor = 2;
  };
}
