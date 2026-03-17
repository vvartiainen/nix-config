{
  inputs,
  userName,
  hostName,
  pkgs,
  ...
}:
{
  imports = [
    inputs.home-manager.darwinModules.home-manager
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  networking.hostName = hostName;
  system.primaryUser = userName;

  system.stateVersion = 6;
}
