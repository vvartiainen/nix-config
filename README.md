# nix-config

My macOS setup managed with Nix flakes, nix-darwin, and Home Manager.
It targets Apple Silicon and is tailored to my machines; feel free to borrow parts.

## Setup

Follow the [new Mac setup](docs/runbooks/new-mac.md). Machine identity and
private modules live outside the repo in `~/.config/nix-config-host/`
([host data](docs/design/host-data.md)).

## Everyday commands

```sh
just check <HOSTNAME>      # lint, evaluate, validate installed agent config
just build <HOSTNAME>      # build and show package changes
just switch <HOSTNAME>     # apply
just up                   # update all flake inputs; pass names for a subset
just rollback             # return to the previous generation
```

`<HOSTNAME>` defaults to the machine's hostname. See
[maintenance](docs/maintenance.md) for checks, updates and backups. Agents
follow [AGENTS.md](AGENTS.md).

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
the workstation configuration.

## Documentation

Everyday pages:

- [Maintenance](docs/maintenance.md): validate, apply, lint, update, roll back,
  Homebrew data, backups
- [Keybindings](docs/keybindings.md): desktop, browser and terminal shortcuts

The rest of `docs/`:

- [`programs/`](docs/programs/): everyday use of one program or area:
  [desktop](docs/programs/desktop.md), [terminal and files](docs/programs/terminal.md),
  [Neovim](docs/programs/neovim.md), [Rex](docs/programs/rex.md),
  [Spotify](docs/programs/spotify.md), [IINA](docs/programs/iina.md),
  [Amphetamine](docs/programs/amphetamine.md), [direnv](docs/programs/direnv.md)
  and [Linux builders](docs/programs/linux-builders.md)
- [`agents/`](docs/agents/): coding agents:
  [comparison](docs/agents/comparison.md),
  [permissions and sandboxes](docs/agents/permissions.md),
  [configuration](docs/agents/config.md), [keybindings](docs/agents/keybindings.md)
  and [quotas, status and history](docs/agents/sessions.md)
- [`runbooks/`](docs/runbooks/): procedures done rarely:
  [new Mac setup](docs/runbooks/new-mac.md),
  [agent forge token](docs/runbooks/forge-token.md) and
  [transcript uploads](docs/runbooks/agent-transcript-uploads.md)
- [`design/`](docs/design/): how things are built and why:
  [host data](docs/design/host-data.md), [modules and dotfiles](docs/design/modules.md),
  [tool ownership](docs/design/tool-ownership.md),
  [T3 Code settings](docs/design/t3-code.md) and
  [agent permissions](docs/design/agent-permissions.md)
