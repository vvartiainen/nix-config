_: {
  nix = {
    enable = true;
    # Flake inputs replace channels; nix-darwin already pins the nixpkgs
    # registry entry and NIX_PATH to this flake's nixpkgs.
    channel.enable = false;
    settings = {
      trusted-users = [
        "root"
      ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # The linux-builder fetches from caches itself instead of receiving
      # every dependency from the host.
      builders-use-substitutes = true;
      # Leave the build sandbox off: on macOS, Nix's Seatbelt profile for the
      # system derivation exceeds the 64 KiB limit ("data object length ...
      # exceeds maximum (65535)"), so darwin-rebuild fails. Agent sandboxes
      # limit what their commands can pass to daemon builds instead.
      sandbox = false;
      # Build locally when a substituter can't be reached, and don't wait long
      # for one.
      fallback = true;
      connect-timeout = 5;
      # Collect garbage during builds when free space drops below 5 GiB,
      # until 20 GiB is free.
      min-free = 5 * 1024 * 1024 * 1024;
      max-free = 20 * 1024 * 1024 * 1024;
    };

    gc = {
      automatic = true;
      options = "--delete-older-than 1w";
    };
    optimise.automatic = true;
  };

  # Keep store maintenance from competing with foreground work.
  launchd.daemons = {
    nix-gc.serviceConfig = {
      ProcessType = "Background";
      LowPriorityIO = true;
    };
    nix-optimise.serviceConfig = {
      ProcessType = "Background";
      LowPriorityIO = true;
    };
  };

  nixpkgs.config.allowUnfree = true;
}
