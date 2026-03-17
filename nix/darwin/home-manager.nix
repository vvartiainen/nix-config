{
  inputs,
  pkgs,
  userName,
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
    users.${userName} = {
      home = {
        username = userName;
        homeDirectory = "/Users/${userName}";
        stateVersion = "25.11";
      };
    };
  };
}
