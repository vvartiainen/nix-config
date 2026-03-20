{
  ...
}:
{
  imports = [
    ../shared/nix.nix
    ../shared/networking.nix
    ./system-settings.nix
    ./homebrew.nix
    ./home-manager.nix
  ];

  system.stateVersion = 6;
  nixpkgs.hostPlatform = "aarch64-darwin";
}
