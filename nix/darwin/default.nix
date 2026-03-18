{
  userName,
  hostName,
  ...
}:
{
  imports = [
    ./home-manager.nix
  ];

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

      # gc = {
      #   automatic = lib.mkDefault true;
      #   options = lib.mkDefault "--delete-older-than 1w";
      # };
      # optimise.automatic = true;
    };
  };

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  networking = {
    inherit hostName;
    computerName = hostName;
  };

  system = {
    primaryUser = userName;
    stateVersion = 6;

    defaults.smb.NetBIOSName = hostName;

    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = true;
    };
  };
}
