{
  pkgs,
  userName,
  hostName,
  repoRoot,
  inputs,
  ...
}:
{
  imports = [
    ../../modules/darwin/nix.nix
    ../../modules/darwin/system-settings.nix
    ../../modules/darwin/default-apps.nix
    ../../modules/darwin/apple-intelligence.nix
    ../../modules/darwin/homebrew.nix
    ../../modules/darwin/linux-builder.nix
    ../../modules/darwin/rosetta-builder.nix
    ../../modules/darwin/signed-binaries.nix
    ../../modules/darwin/programs/claude-code.nix
    ../../modules/darwin/programs/codexbar.nix
    ../../modules/darwin/programs/vicinae.nix
    ../../modules/darwin/programs/rex.nix
    ../../modules/darwin/programs/sketchybar.nix
    ../../modules/darwin/programs/spotlight.nix
    ../../modules/darwin/programs/skhd.nix
    ../../modules/darwin/programs/yabai.nix
  ];

  networking = {
    inherit hostName;
    computerName = hostName;
  };

  system.defaults.smb.NetBIOSName = hostName;

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
}
