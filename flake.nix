{
  description = "vvartiainen nix-config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cli-toolbox = {
      url = "git+ssh://git@github.com/vvartiainen/cli-toolbox.git";
      # TODO: Make repo public and use this instead
      # url = "github:vvartiainen/cli-toolbox";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      nixpkgs,
      home-manager,
      cli-toolbox,
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
      darwinConfigurations.${hostName} = nix-darwin.lib.darwinSystem {
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
