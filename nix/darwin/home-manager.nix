{
  inputs,
  pkgs,
  userName,
  repoRoot,
  ...
}:

{
  imports = [
    inputs.home-manager.darwinModules.home-manager
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
      imports = [ ../shared/home-manager.nix ];
      home = {
        username = userName;
        homeDirectory = "/Users/${userName}";
        stateVersion = "25.11";
      };
    };
  };
}
