{
  lib,
  pkgs,
  hardware,
  userName,
  repoRoot,
  inputs,
  ...
}:
{
  imports = [
    ../../modules/shared/nix.nix
    ../../modules/shared/networking.nix
    ../../modules/darwin/system-settings.nix
    ../../modules/darwin/homebrew.nix
    ../../modules/darwin/programs/yabai.nix
  ];

  users.users.${userName} = {
    name = userName;
    home = "/Users/${userName}";
    shell = pkgs.zsh;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup-before-nix";
    extraSpecialArgs = {
      inherit repoRoot inputs;
    };
    users.${userName} = {
      imports = [
        ../../modules/home
        ../../modules/darwin/programs
      ];
      home = {
        username = userName;
        homeDirectory = "/Users/${userName}";
        stateVersion = "25.11"; # This should not be changed even when flakes are updated!
      };
    };
  };

  system.stateVersion = 6; # This should not be changed even when flakes are updated!
  nixpkgs.hostPlatform = "aarch64-darwin";

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
