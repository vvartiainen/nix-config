_: {
  nix = {
    enable = true;
    settings = {
      trusted-users = [
        "root"
      ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # nix-darwin pins `nixpkgs` in the system registry to this flake's
      # input. Skip the global registry so `nixpkgs#…` resolves offline.
      flake-registry = "";
    };

    gc = {
      automatic = true;
      options = "--delete-older-than 1w";
    };
    optimise.automatic = true;
  };

  nixpkgs.config.allowUnfree = true;
}
