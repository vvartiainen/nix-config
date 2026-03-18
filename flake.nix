{
  description = "vvartiainen nix-config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-25.11-darwin";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
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
      userName = "vvarti";
      hostName = "default";
      repoRoot = "/Users/${userName}/prog/nix-config";
    in
    {
      darwinConfigurations.${hostName} = darwin.lib.darwinSystem {
        modules = [
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
