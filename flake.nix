{
  description = "vvartiainen nix-config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      darwin,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      defaultConfig = {
        userName = "vvarti";
        hostName = "mbp";
        repoRoot = "/Users/vvarti/prog/nix-config";
      };

      localConfigPath = ./local-config.nix;
      userConfig = if builtins.pathExists localConfigPath then import localConfigPath else defaultConfig;

      inherit (userConfig)
        userName
        hostName
        repoRoot
        ;
    in
    {
      darwinConfigurations.${hostName} = darwin.lib.darwinSystem {
        modules = [
          home-manager.darwinModules.home-manager
          ./nix/darwin/default.nix
        ];

        specialArgs = {
          inherit
            inputs
            self
            userName
            hostName
            repoRoot
            ;
        };
      };
    };
}
