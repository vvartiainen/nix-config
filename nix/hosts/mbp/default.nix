{
  pkgs,
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
    ephemeral = true;
    maxJobs = 4;
    config = {
      virtualisation = {
        darwin-builder = {
          diskSize = 40 * 1024;
          memorySize = 8 * 1024;
        };
        cores = 6;
      };
    };
  };
}
