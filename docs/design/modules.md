# Modules and dotfiles

## Composition

`nix/hosts/<host>/` only composes: it explicitly imports the darwin modules it
uses and sets host facts from [host data](host-data.md). Program configuration
lives in one module per program under `nix/modules/home/programs/` or
`nix/modules/darwin/programs/`; a darwin program module also declares the
Homebrew cask it needs. AI tools are grouped under
`nix/modules/home/programs/ai/` into clients, hooks and shared tooling.

Keep each program module importable on its own. Other flakes, such as private
workstations or agent sandboxes, import single modules instead of the whole
workstation configuration; the [README](../../README.md#repository-layout) has
an example.

## Dotfiles

App configs live in `dotfiles/` and are linked per file with
`mkOutOfStoreSymlink` to the checkout at `repoRoot`, so edits apply without a
rebuild and `~/.config/<app>` stays writable. A new dotfile needs `git add`
and a rebuild before it gets a link; gitignored files are skipped.

Neovim nightly is the exception: its configuration and plugins are built into
the store, while the default editor uses the live links; see
[Neovim](../programs/neovim.md).
