{
  inputs,
  pkgs,
  userName,
  ...
}:
let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ inputs.spicetify-nix.darwinModules.spicetify ];

  # Installs the spiced Spotify.app to /Applications/Nix Apps; do not install
  # pkgs.spotify or the Spotify cask as well.
  programs.spicetify = {
    enable = true;
    theme = spicePkgs.themes.catppuccin;
    colorScheme = "mocha";
  };

  # Spotify updates itself on launch, which replaces the spiced store copy with
  # an unpatched download. Lock its update cache so only the Nix build runs.
  # https://github.com/NixOS/nixpkgs/issues/404502
  home-manager.users.${userName} = { lib, ... }: {
    home.activation.disableSpotifyUpdates = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      updateDir="$HOME/Library/Application Support/Spotify/PersistentCache/Update"
      if [[ ! -d "$updateDir" ]] || ! /usr/bin/stat -f '%Sf' "$updateDir" | grep -q uchg; then
        rm -rf "$updateDir"
        mkdir -p "$updateDir"
        /usr/bin/chflags uchg "$updateDir"
      fi
    '';
  };
}
