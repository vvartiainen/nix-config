# Parallel Nix-managed Neovim

After building and manually applying the configuration, run the two setups side
by side:

```sh
nvim path/to/file       # Homebrew binary and live dotfiles
nvim-nix path/to/file   # Nix binary and build-time config snapshot
```

The default `EDITOR`, `VISUAL`, and integrations use `nvim`. The `nvim-nix`
wrapper selects the Nix binary and sets `NVIM_APPNAME=nvim-nix`, selecting
separate standard directories: `~/.config/nvim-nix`, `~/.local/share/nvim-nix`,
`~/.local/state/nvim-nix`, and `~/.cache/nvim-nix` (or their XDG overrides).
Setting `NVIM_APPNAME` alone on the Homebrew binary only selects another config.

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
nvim-nix path/to/file
# or, from outside the shell:
nix develop --command nvim-nix path/to/file
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
to update `nvim-nix`. The original editor sees those edits immediately.
The experimental extras list is the immutable `lazyvim.json` snapshot; change
the repository file rather than using `:LazyExtras`.

Add plugin packages or parser languages in
[`neovim.nix`](../nix/modules/home/programs/neovim.nix) when enabling more extras.
Nix-specific loading and tool overrides live beside that module under
[`neovim/`](../nix/modules/home/programs/neovim).

## Compare the editors

Compare `:checkhealth`, file search, completion, formatting, LSP, tests, and
debugging on the same projects, inside the same dev shell. In either editor:

```vim
:echo v:progpath
:lua for _, key in ipairs({ "config", "data", "state", "cache" }) do print(key, vim.fn.stdpath(key)) end
:lua print(vim.fn.exepath("nil"))
```

In `nvim-nix`, `:Lazy` plugin directories should point into `/nix/store`.
Use `:ConformInfo` and `:LspInfo` to check project tool resolution.
