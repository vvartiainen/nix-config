{
  pkgs,
  userName,
  repoRoot,
  ...
}:
{
  imports = [
    ../shared/nix.nix
    ../shared/networking.nix
    ./system-settings.nix
    ./homebrew.nix
  ];

  users.users.${userName} = {
    name = "${userName}";
    home = "/Users/${userName}";
    shell = pkgs.zsh;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup-before-nix";
    extraSpecialArgs = {
      inherit repoRoot;
    };
    users.${userName} = {
      imports = [
        ../shared/home-manager.nix
        ./programs
      ];
      home = {
        username = userName;
        homeDirectory = "/Users/${userName}";
        stateVersion = "25.11";
      };
    };
  };

  system.stateVersion = 6;
  nixpkgs.hostPlatform = "aarch64-darwin";
}
