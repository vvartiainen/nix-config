# nix-config

My macOS setup managed with Nix flakes, nix-darwin, and Home Manager.
It targets Apple Silicon and is tailored to my machines; feel free to borrow parts.

## Setup

Install Xcode, Homebrew, just, and Nix with flakes support, then clone this repo.
Follow the [new Mac setup](docs/runbooks/new-mac.md) for prerequisites, private
host data and the manual steps after the first activation.
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

See [maintenance](docs/maintenance.md) for repository checks, updates,
generation selection and backups.
Agents follow [AGENTS.md](AGENTS.md) and use the public fixture for validation.

## Repository layout

- `flake.nix` / `flake.lock`: entrypoint and pinned inputs
- `nix/hosts/`: host identity and composition roots
- `nix/validation/`: repository checks, agent config validation, schemas, and validation hooks
- `nix/modules/home/`: Home Manager and CLI program modules; AI tools group clients, hooks, and shared tooling
- `nix/modules/darwin/`: macOS system and program modules, explicitly imported by hosts
- `dotfiles/`: app configs, generally linked live with `mkOutOfStoreSymlink`
- `tests/`: behavior checks grouped by program or subsystem

Other flakes can import individual Home Manager modules directly, for example
`${inputs.nix-config}/nix/modules/home/programs/lazygit.nix`, without importing
the workstation configuration. Lazygit includes delta; its Neovim editor preset
expects a configured `nvim` on `PATH`.

## Documentation

Everyday pages:

- [Maintenance](docs/maintenance.md): validate, apply, lint, update, roll back,
  Homebrew data, backups
- [Keybindings](docs/keybindings.md): desktop, browser and terminal shortcuts

The rest of `docs/`:

- [`programs/`](docs/programs/): everyday use of one program or area:
  [desktop](docs/programs/desktop.md), [terminal and files](docs/programs/terminal.md),
  [Neovim](docs/programs/neovim.md), [Rex](docs/programs/rex.md) and
  [Linux builders](docs/programs/linux-builders.md)
- [`agents/`](docs/agents/): coding agents:
  [permissions and sandboxes](docs/agents/permissions.md),
  [configuration](docs/agents/config.md), [keybindings](docs/agents/keybindings.md)
  and [quotas, status and history](docs/agents/sessions.md)
- [`runbooks/`](docs/runbooks/): procedures done rarely, such as
  [new Mac setup](docs/runbooks/new-mac.md)
