# Neovim and language tools

## Choose the editor

```sh
nvim path/to/file           # Homebrew binary, live dotfiles; default editor
nvim-nightly path/to/file   # Pinned nightly, build-time config and plugins
```

Nightly uses separate config, data, state and cache directories through
`NVIM_APPNAME=nvim-nightly`, so it can run beside the default editor. Its plugins
and parsers come from Nix; Mason and plugin installation are disabled there.
The live editor retains Mason for formatter/debugger fallbacks.

## Language tools and formatting

Nix owns the common language-server baseline and mise the runtimes and project
versions; see [tool ownership](../design/tool-ownership.md). Both editors inherit the project's `PATH`; project dependencies or
an optional dev shell can override the baseline. Project-only formatters,
debuggers and test runners still need installation; nightly has no Mason fallback.
Removing a declaration does not uninstall old mise/Mason tools or their shims.
Check resolution before removing them:

```sh
type -a tsc typescript-language-server nil ruff
```

Inside each editor, use `:LspInfo` (or `:checkhealth vim.lsp`) to inspect actual
clients and commands, and `:ConformInfo` for formatter selection. Shell resolution
alone does not prove which server is running. JavaScript/web formatting selects
Oxfmt, Biome or Prettier from the nearest supported project configuration;
provide the selected tool in the project. Python uses Ruff.

## Change or update nightly

Edit [the Lua config](../../dotfiles/nvim) and rebuild for nightly; the live editor
sees edits immediately. Change nightly extras in `dotfiles/nvim/lazyvim.json`
rather than `:LazyExtras`. Plugin/parser packages are declared in
[neovim.nix](../../nix/modules/home/programs/neovim.nix); the common tool baseline is
[language-tools.nix](../../nix/modules/home/programs/language-tools.nix).

Update the nightly input with `just up neovim-nightly`, review the lock diff,
then build and apply manually. Plugin versions follow the main nixpkgs pin,
independently of nightly. Compare completion, formatting, LSP, debugging and
tests in both editors before changing the default editor.

Markdown line-length diagnostics are hidden from inline text, but remain
available through `<leader>cd` (float) and `<leader>xx` (list). For an optional
80-column guide, use `:setlocal colorcolumn=81`.
