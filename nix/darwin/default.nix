{
  inputs,
  pkgs,
  userName,
  hostName,
  ...
}:
{
  imports = [
    ./home-manager.nix
  ];

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
  };

  nixpkgs.hostPlatform = "aarch64-darwin";

  system = {
    primaryUser = userName;
    stateVersion = 6;
  };

  networking = {
    hostName = hostName;
  };

}
