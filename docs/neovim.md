# Parallel Neovim nightly

After building and manually applying the configuration, run the two setups side
by side:

```sh
nvim path/to/file           # Homebrew binary and live dotfiles
nvim-nightly path/to/file   # Pinned nightly and build-time config snapshot
```

The default `EDITOR`, `VISUAL`, and integrations use `nvim`. The `nvim-nightly`
wrapper selects the Nix-built nightly binary and sets
`NVIM_APPNAME=nvim-nightly`, selecting separate standard directories:
`~/.config/nvim-nightly`, `~/.local/share/nvim-nightly`,
`~/.local/state/nvim-nightly`, and `~/.cache/nvim-nightly` (or their XDG overrides).
The old `nvim-nix` command is replaced by `nvim-nightly`; its existing data
directories are left on disk and are not reused.
Setting `NVIM_APPNAME` alone on the Homebrew binary only selects another config.

## Update nightly

The nightly binary comes from `nix-community/neovim-nightly-overlay`, pinned in
`flake.lock` with its own build dependencies. It does not update automatically.
To refresh only that input (from the repository root):

```sh
nix flake update neovim-nightly
```

Review the lock-file diff, rebuild, and apply the configuration manually. Plugin
versions still come from the repository's existing `nixpkgs` pin; updating nightly
does not update those plugins. The nightly input keeps its own dependencies so
its Neovim build matches upstream. Stable `nvim` remains the Homebrew binary.

## Plugins and project tools

The experimental setup packages the existing Lua settings, LazyVim extras,
plugins, and Treesitter parsers in the Nix store. Lazy handles loading, while
plugin installation, builds, update checks, Lua rocks, and project-local Lazy
specs are disabled. Mason and its LSP/DAP integrations are disabled. Plugin
versions come from `nixpkgs` in `flake.lock`, rather than the live editor's
`lazy-lock.json`.

Launch it inside a project dev shell so language servers, formatters, linters,
debug adapters, and test runners come from that shell:

```sh
nix develop
nvim-nightly path/to/file
# or, from outside the shell:
nix develop --command nvim-nightly path/to/file
```

The launcher inherits `PATH`; it does not install or prepend development tools.
For example, a Nix project can supply `nil`, `nixfmt`, and `statix`; a Python
project can supply `pyright`, `ruff`, `black`, and `debugpy`; a Go project can
supply `gopls`, `go`, and `delve`. Debugging expects adapters on `PATH`, including
`codelldb`, `debugpy-adapter`, and `dlv` as appropriate. Project tools such as
Prettier/ESLint and test runners may resolve from local `node_modules`. Add
missing tools to the project shell; there is no Mason fallback.

Go is the exception: [`go.nix`](../nix/modules/home/programs/go.nix) installs
`gopls`, `golangci-lint`, and `delve` globally to match the Go toolchain, so
both editors find them without a dev shell. The live editor's Mason skips them.
`neovim.nix` also installs the `tree-sitter` CLI for the live editor's parser
builds, so LazyVim doesn't fetch it with Mason.

## Change the configuration

Edit Lua settings and extras in [`dotfiles/nvim`](../dotfiles/nvim) and rebuild
to update `nvim-nightly`. The original editor sees those edits immediately.
The experimental extras list is the immutable `lazyvim.json` snapshot; change
the repository file rather than using `:LazyExtras`.

Add plugin packages or parser languages in
[`neovim.nix`](../nix/modules/home/programs/neovim.nix) when enabling more extras.
Nix-specific loading and tool overrides live beside that module under
[`neovim/`](../nix/modules/home/programs/neovim).

Markdown line-length diagnostics (`markdownlint` rule `MD013`) are hidden from
inline virtual text across projects. The rule remains enabled: use `<leader>cd`
to open the diagnostic float or `<leader>xx` to open the diagnostics list.
Other diagnostics still show inline. This is configured in
[`lsp.lua`](../dotfiles/nvim/lua/plugins/lsp.lua).

For an optional vertical guide after 80 columns, run `:setlocal colorcolumn=81`.
To enable it by default, add `vim.opt.colorcolumn = "81"` to
[`options.lua`](../dotfiles/nvim/lua/config/options.lua).

## Compare the editors

Compare `:checkhealth`, file search, completion, formatting, LSP, tests, and
debugging on the same projects, inside the same dev shell. In either editor:

```vim
:echo v:progpath
:lua for _, key in ipairs({ "config", "data", "state", "cache" }) do print(key, vim.fn.stdpath(key)) end
:lua print(vim.fn.exepath("nil"))
```

In `nvim-nightly`, `:Lazy` plugin directories should point into `/nix/store`.
Use `:ConformInfo` and `:LspInfo` to check project tool resolution.
