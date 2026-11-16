# Spotify

Spotify is the [spicetify](https://spicetify.app) build from
`nix/modules/darwin/programs/spotify.nix`, themed with Catppuccin Mocha and
installed to `/Applications/Nix Apps/Spotify.app`. Do not add Spotify or
`spicetify-cli` to Homebrew. Theme and extension changes go in
`programs.spicetify` and need an apply, since the app is rebuilt.

## Updates

Spotify updates itself on launch and would replace the spiced build with an
unpatched download. Activation therefore locks
`~/Library/Application Support/Spotify/PersistentCache/Update` with the `uchg`
flag; see [nixpkgs#404502](https://github.com/NixOS/nixpkgs/issues/404502).
Check it with `ls -ldO` on that directory. If Spotify opens unthemed, quit it
and apply the configuration again.
