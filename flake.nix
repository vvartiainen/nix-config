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
      url = "github:vvartiainen/cli-toolbox";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };

    # asmvik/yabai plus macOS 27 scripting-addition offsets.
    yabai-src = {
      url = "github:ImTheSquid/yabai";
      flake = false;
    };

    # Per-machine identity, kept out of this repo; see nix/host-unset.
    host = {
      url = "path:./nix/host-unset";
      flake = false;
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
      host = import inputs.host;

      inherit (host)
        userName
        hostName
        repoRoot
        ;

      # Nested virtualization needs an M3 or newer and macOS 15+.
      hardware = {
        inherit (host) nestedVirtualization;
      };
    in
    {
      darwinConfigurations.${hostName} = nix-darwin.lib.darwinSystem {
        modules = [
          home-manager.darwinModules.home-manager
          ./nix/hosts/mbp
          # Private modules from the host data, e.g. work-only config.
          { home-manager.sharedModules = host.homeModules or [ ]; }
        ]
        ++ host.darwinModules or [ ];

        specialArgs = {
          inherit
            inputs
            self
            hardware
            userName
            hostName
            repoRoot
            ;
        };
      };
    };
}
