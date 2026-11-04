{ userName, ... }:
{
  homebrew.casks = [
    "vicinae"
    # Keep Raycast installed during the trial: cleanup=zap would delete its data.
    "raycast"
  ];

  home-manager.users.${userName}.xdg.dataFile."vicinae/scripts/eject-all-disks.sh".source =
    ../../../../dotfiles/vicinae/scripts/eject-all-disks.sh;

  # Onboarding, login startup and Cmd+Space are configured in Vicinae itself.
  # Keep settings.json writable so GUI changes persist; see docs/setup.md.
}
