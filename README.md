# nix-config

My macOS setup managed with Nix flakes, nix-darwin, and Home Manager.
It targets Apple Silicon and is tailored to my machines; feel free to borrow parts.

## Setup

Install Xcode, Homebrew, just, and Nix with flakes support, then clone this repo.
Follow the [setup guide](docs/setup.md) for prerequisites and private host data.
From the repository root:

```sh
just init-host <HOSTNAME>  # generate host data; review it before bootstrapping
just bootstrap <HOSTNAME> # first activation
```

Machine identity and private modules live outside the repo in
`~/.config/nix-config-host/`. Use its `hostName` for `<HOSTNAME>`; recipes
default to the machine's hostname.

## Everyday commands

Validate your real host configuration before applying changes manually:

```sh
just check <HOSTNAME>      # lint, evaluate, and validate installed agent config
just build <HOSTNAME>      # build, show package changes, validate installed agent config
just switch <HOSTNAME>     # apply
just switch <HOSTNAME> 1   # apply without running Homebrew bundle
just up                   # update all flake inputs; pass names to update a subset
just rollback             # return to the previous system generation
just clean                # remove generations older than 7 days and collect garbage
```

See the [maintenance guide](docs/maintenance.md) for fixture validation,
generation selection, Linux builds, backups, and desktop notes.
Agents follow [AGENTS.md](AGENTS.md) and use the public fixture for validation.

## Repository layout

- `flake.nix` / `flake.lock`: entrypoint and pinned inputs
- `nix/hosts/`: host composition roots
- `nix/modules/shared/`: shared system modules
- `nix/modules/home/`: Home Manager and CLI program modules
- `nix/modules/darwin/`: macOS system and program modules
- `dotfiles/`: app configs, generally linked live with `mkOutOfStoreSymlink`
- `tests/`: behavior checks grouped by program or subsystem

Other flakes can import individual Home Manager modules directly, for example
`${inputs.nix-config}/nix/modules/home/programs/lazygit.nix`, without importing
the workstation configuration. Lazygit includes delta; its Neovim editor preset
expects a configured `nvim` on `PATH`.

## Documentation

- [Setup and host data](docs/setup.md)
- [Maintenance and validation](docs/maintenance.md)
- [Desktop, browser and terminal keybindings](docs/keybindings.md)
- [Neovim and language tools](docs/neovim.md)
- [Agent CLI keybindings](docs/agent-keybindings.md)
- [Agent permissions and sandboxes](docs/agent-permissions.md)
- [Per-project MCP servers and skills](docs/agent-project-tools.md)

Repository guides cover current usage and essential rationale. Implementation
details, plans, and review notes live in `backlog-nix-config`, also available
through `bl`, `bl review`, and `bl handoffs` from this repo. Read Backlog documents
with the MCP `document_view` tool using these IDs:

| Backlog document | Detailed reference |
| --- | --- |
| doc-3 | AI CLI permissions and sandbox behavior |
| doc-5 | Desktop and terminal integration details |
| doc-6 | Maintenance and builder implementation notes |
| doc-7 | Neovim and language-tool implementation notes |
| doc-8 | Agent project tooling and configuration implementation |
