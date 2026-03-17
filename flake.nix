{
  description = "vvartiainen nix-config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-25.11-darwin";
    darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ self, darwin, ... }:
    let
      userName = "vvarti";
      hostName = "default";
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
            ;
        };
      };
    };
}
