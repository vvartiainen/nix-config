{
  userName,
  ...
}:
{
  nix = {
    enable = true;
    settings = {
      trusted-users = [
        "root"
        userName
      ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };

    gc = {
      automatic = true;
      options = "--delete-older-than 1w";
    };
    optimise.automatic = true;
  };

  nixpkgs.config.allowUnfree = true;
}
