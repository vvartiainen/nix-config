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
}
