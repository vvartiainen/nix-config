# Spotify

Spotify is the [spicetify](https://spicetify.app) build from
`nix/modules/darwin/programs/spotify.nix`: the Nix package with the Catppuccin
theme in Mocha colors patched in. Nix installs it to
`/Applications/Nix Apps/Spotify.app`, and Homebrew no longer provides Spotify or
`spicetify-cli`. Do not add either back; the module installs the app for you.

## Theme and extensions

`programs.spicetify` in the module owns the configuration. `theme` and
`colorScheme` come from `inputs.spicetify-nix.legacyPackages.<system>.themes`,
and `enabledExtensions` takes entries from the same set's `extensions`. Apply
the configuration after a change, since the app is rebuilt rather than patched
in place.

## Updates

Spotify updates itself on launch and would replace the spiced build with an
unpatched download. Activation therefore locks
`~/Library/Application Support/Spotify/PersistentCache/Update` with the `uchg`
flag; see [nixpkgs#404502](https://github.com/NixOS/nixpkgs/issues/404502).
Check it with `ls -ldO` on that directory. If Spotify opens unthemed, quit it
and apply the configuration again.
