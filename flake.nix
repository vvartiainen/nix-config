{
  description = "vvartiainen nix-config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Keep the Rosetta VM image independent of desktop package updates.
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Use the upstream package and dependency pins for the experimental editor.
    neovim-nightly.url = "github:nix-community/neovim-nightly-overlay";

    # Keep upstream dependency pins so its binary cache can be used.
    vicinae.url = "github:vicinaehq/vicinae";

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

    # Track the preview channel; Nix locks the immutable release URL that it
    # redirects to, so `nix flake update rex` moves to the newest preview.
    # The CLI and the GUI build in nix/modules/darwin/programs/rex.nix share an
    # API revision, so bump that app pin together with this input.
    rex = {
      url = "https://pkgs.superlogical.com/rex/nix/preview.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };

    # On-demand Lima/Rosetta Linux builder; update its VM image separately.
    nix-rosetta-builder = {
      url = "github:cpick/nix-rosetta-builder";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    # asmvik/yabai fork with macOS 27.0-27.2 support. Pinned to a release tag:
    # the scripting addition from this source is injected into Dock as root.
    yabai-src = {
      url = "github:Christian-SC26/yabai/v7.3.2";
      flake = false;
    };

    # Per-machine identity, kept out of this repo; see nix/host-unset.
    # TODO: Should probably be required in some default location instead of override in justfile?
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
      packages.aarch64-darwin.validate-agent-config =
        (import ./nix/validation/agent-config-validation.nix {
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        }).validator;

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
