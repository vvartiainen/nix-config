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

## Plugins and shared language tools

The experimental setup packages the existing Lua settings, LazyVim extras,
plugins, and Treesitter parsers in the Nix store. Lazy handles loading, while
plugin installation, builds, update checks, Lua rocks, and project-local Lazy
specs are disabled. Mason and its LSP/DAP integrations are disabled. Plugin
versions come from `nixpkgs` in `flake.lock`, rather than the live editor's
`lazy-lock.json`.

After manually applying the configuration, both editors find the common
language servers through the Home Manager profile. A dev shell is optional.
The shared baseline lives in
[`language-tools.nix`](../nix/modules/home/programs/language-tools.nix), so agents
and command-line tools can use it too.

The nightly launcher inherits `PATH` without prepending tools. Projects can
still override baseline versions through their existing mise configuration,
local dependencies, or an optional dev shell:

```sh
nix develop --command nvim-nightly path/to/file
```

Project-only formatters, debug adapters and test runners still need their own
installation. Nightly has no Mason fallback. Tools such as Prettier/ESLint may
resolve from local `node_modules`; use `:ConformInfo` and LSP health information
to check the actual command.

## Language-server ownership

Nix owns the common language-server baseline. Mise keeps language runtimes and
project-specific versions. Neither editor uses Mason's LSP installation or
automatic activation integration.

| Languages/tools | Nix baseline |
| --- | --- |
| TypeScript/JavaScript | `typescript` supplies native `tsc` with LSP support; `typescript-language-server` supplies the separate tsserver-based LSP for other clients. |
| Web frameworks and diagnostics | Svelte, Tailwind CSS, Biome and Oxlint servers; the extracted VS Code HTML/CSS/JSON/ESLint servers. |
| Python | Pyright and Ruff, including Ruff formatting. |
| Shell, Lua and Markdown | bash-language-server, lua-language-server and Marksman. |
| Nix, TOML, Terraform and YAML | nil, Tombi, terraform-ls and yaml-language-server. |
| C/C++, Docker and Zig | clangd from clang-tools, Dockerfile/Compose servers and ZLS. Match project Zig and ZLS versions when overriding them. |
| Go | [`go.nix`](../nix/modules/home/programs/go.nix) owns gopls and associated Go tools beside the Go toolchain. |
| Rust | [`rust.nix`](../nix/modules/home/programs/rust.nix) owns rust-analyzer beside Rust; Rustaceanvim configures it separately. |
| Swift/SourceKit | The Apple toolchain supplies sourcekit-lsp on macOS. Linux needs a suitable Swift toolchain or the server disabled. |

`neovim.nix` also installs the tree-sitter CLI for live-editor parser builds.
The existing public package list supplies nixfmt and statix alongside nil.

### TypeScript and agent commands

The selected LazyVim `tsc` extra runs the native TypeScript 7+ compiler as
`tsc --lsp --stdio`. It is separate from `typescript-language-server`, which
uses the older tsserver protocol internally. Both executables are installed
by Nix; their global mise declarations and lock entries are removed. The
Nix language-server package includes its Node wrapper and fallback tsserver.

Svelte uses the explicit `svelte` LSP configuration and Nix's `svelteserver`.
Keep LazyVim's Svelte extra disabled: it unconditionally looks for
`typescript-svelte-plugin` inside Mason's Svelte package for `vtsls`, even when
the selected TypeScript server is native `tsc`. The existing Treesitter and
Conform settings retain Svelte parsing and formatting without that extra.

TypeScript 7.0.2 can report `context canceled` and exit code 1 after a normal
LSP shutdown. This is a [known upstream issue](https://github.com/microsoft/TypeScript/issues/64742),
reproduced with the Nix package; initialization succeeds.

OpenCode and Copilot use `lib.getExe pkgs.typescript` in their Nix modules.
This generates the package's executable path in the installed agent config,
without committing a store hash, username or mise installation path. It also
avoids the Copilot sandbox's previous inability to follow a mise shim into
Homebrew. These agent commands deliberately use the shared baseline; editor
and project commands can still choose a project TypeScript version.

### Resolution and existing installations

Both editors preserve inherited project/profile `PATH`. The live editor appends
Mason's bin directory after it; nightly disables Mason entirely. Mason remains
available for other formatter/debugger fallbacks, while its install list skips
Nix-owned Go tools, Biome and Ruff. An old Mason-only server may still be found
as a last fallback in the live editor.

Removing mise declarations and Mason installation requests does not uninstall
existing tools or remove their shims. After manually applying, open a fresh
shell and check `type -a tsc typescript-language-server nil ruff` and the editor
commands below. Confirm the Nix baseline or intended project version wins
before manually cleaning up obsolete installations. No dev shell or committed
machine-specific executable path is required for the shared baseline.

### Formatter selection

Conform uses the project's executables before Mason fallbacks. Python uses
`ruff_format` instead of Black. Go, Rust, Terraform and Zig use their toolchain's
`gofmt`, `rustfmt`, `terraform fmt` and `zig fmt`. Lua and Nix retain Stylua and
nixfmt; Markdown retains the enabled extra's Prettier, markdownlint-cli2 and
optional table-of-contents chain.

JavaScript/TypeScript, JSON, CSS/SCSS and component files select Oxfmt, Biome or
Prettier from the nearest supported configuration, rather than running competing
formatters sequentially. Without a configuration, JavaScript/TypeScript fall
back to Biome, and JSON/CSS/component files to Prettier (subject to its existing
configuration requirement). Provide the selected tool in the project.

Shell formatting uses shfmt; ShellCheck diagnostics stay in nvim-lint. Zsh and
SQL no longer force Bash-oriented tools or an undeclared SQL formatter. Ruff
and Biome come from Nix. Mason retains other formatter fallbacks, while the Markdown and Oxc extras
request markdownlint-cli2 and Oxfmt. Existing Black, markdownlint and Rustywind
installations are left on disk; they are no longer explicitly requested here.

### Check actual resolution

Open a representative source file from the same project environment in each
editor. Run `:LspInfo` (or `:checkhealth vim.lsp`) and inspect attached clients:

```vim
:lua for _, c in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do print(c.name, vim.inspect(c.config.cmd)) end
:lua for _, exe in ipairs({ "tsc", "typescript-language-server", "gopls", "rust-analyzer", "nil" }) do print(exe, vim.fn.exepath(exe)) end
```

An empty executable path means it is absent from that editor's `PATH`. A server
may use an absolute or project-local command, or a command function, so combine
this output with its LSP health information; shell `type -a` alone cannot prove
which server is running. For formatter selection, also use `:ConformInfo`.
Record the selected clients and executable owners before removing an installer.

The live and nightly editors use different plugin pins, so check both rather
than assuming their server commands match. Add other commonly used servers to
the shared Nix module; use a project override for a specific version.

The ownership regression check reads existing plugins without installing them
and uses temporary XDG directories and synthetic executables:

```sh
NVIM_TEST_PLUGINS="$HOME/.local/share/nvim/lazy" nvim --clean -i NONE -n --headless \
  -l nix/modules/home/programs/neovim/test-tools.lua
```

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
debugging on the same projects, first with the shared baseline and then with
any project overrides. In either editor:

```vim
:echo v:progpath
:lua for _, key in ipairs({ "config", "data", "state", "cache" }) do print(key, vim.fn.stdpath(key)) end
:lua print(vim.fn.exepath("nil"))
```

In `nvim-nightly`, `:Lazy` plugin directories should point into `/nix/store`.
Use `:ConformInfo` and `:LspInfo` to check project tool resolution.
