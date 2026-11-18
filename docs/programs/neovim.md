# Neovim and language tools

## Choose the editor

```sh
nvim path/to/file           # Homebrew binary, live dotfiles; default editor
nvim-nightly path/to/file   # Pinned nightly, build-time config and plugins
```

Nightly runs beside the default editor (`NVIM_APPNAME=nvim-nightly`). Its
plugins and parsers come from Nix, without Mason; the default editor keeps
Mason for formatter and debugger fallbacks.

## Language tools and formatting

Nix provides the common language servers and mise the runtimes
([tool ownership](../design/tool-ownership.md)). Both editors use the project's
`PATH`, so a project or dev shell can override them; project-only formatters,
debuggers and test runners come from the project.

```sh
type -a tsc typescript-language-server nil ruff   # which binary wins
```

In the editor, `:LspInfo` shows running servers and `:ConformInfo` the chosen
formatter. Web files use Oxfmt, Biome or Prettier from the nearest project
config; Python uses Ruff.

## Change or update nightly

Edit [the Lua config](../../dotfiles/nvim); the default editor sees edits
immediately, nightly after a rebuild. Change nightly extras in
`dotfiles/nvim/lazyvim.json`, not `:LazyExtras`. Plugins are declared in
[neovim.nix](../../nix/modules/home/programs/neovim.nix) and follow the main
nixpkgs pin; the tool baseline is in
[language-tools.nix](../../nix/modules/home/programs/language-tools.nix).

```sh
just up neovim-nightly   # then review the lock diff, build and apply
```

Markdown line-length diagnostics are hidden inline; see them with
`<leader>cd` or `<leader>xx`. For a guide, `:setlocal colorcolumn=81`.
