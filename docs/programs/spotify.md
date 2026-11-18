# Spotify

Spotify is the [spicetify](https://spicetify.app) build from
`nix/modules/darwin/programs/spotify.nix`, installed to
`/Applications/Nix Apps/Spotify.app`. Change themes and extensions in
`programs.spicetify` and apply. Do not add Spotify or `spicetify-cli` to
Homebrew.

Activation blocks Spotify's self-update by locking
`~/Library/Application Support/Spotify/PersistentCache/Update`
([nixpkgs#404502](https://github.com/NixOS/nixpkgs/issues/404502)); check
it with `ls -ldO`. If Spotify opens unthemed, quit it and apply again.
