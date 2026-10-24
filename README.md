# nix-config

My macOS setup managed with Nix flakes, nix-darwin, and Home Manager.

Don't expect this to work out of the box for you, but feel free to borrow anything!

## Repository layout

- `flake.nix`: flake entrypoint, inputs, and `darwinConfigurations.<hostName>`
- `nix/hosts/`: per-host composition roots
  - `mbp/`: wires shared, home, and darwin modules for this machine profile
- `nix/modules/shared/`: system-level modules that are not platform-specific (`nix`, `networking`)
- `nix/modules/home/`: Home Manager user base and CLI program modules
  - `programs/`: one Home Manager module per program (`zsh`, `fzf`, `starship`, etc.)
  - `programs/ai/`: AI CLI utilities (`cursor-cli`, `codex`, `opencode`, Copilot CLI, Pi) plus shared MCP wiring
- `nix/modules/darwin/`: macOS system modules (`homebrew`, `system-settings`) and macOS HM programs
  - `programs/`: macOS-specific Home Manager modules (`yabai`, `skhd`, `sketchybar`, `onepassword`)
- `dotfiles/`: actual config files for apps (`nvim`, `tmux`, `yabai`, `skhd`, etc.)
  - Using `mkOutOfStoreSymlink` so updates in these files are reflected directly
  - Might want to move some of these to "more pure" / immutable configs at some point

## Agent CLI keybindings

See the [keybinding guide](docs/agent-keybindings.md) for shared shortcuts and the comparison matrix.

See the [permission guide](docs/agent-permissions.md) for command rules, sandboxes, and approval behavior.

## Prerequisites

- macOS (Apple Silicon expected by current config)
- Xcode
- Homebrew
- just (`brew install just`)

Apple does not expose these as nix-darwin options. Run them once on a new machine (safe to re-run):

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
softwareupdate --install-rosetta --agree-to-license
```

Rosetta is required for `x86_64-linux` builds on the VZ linux-builder. The Xcode license must be accepted before `xcodebuild` and some Homebrew formulas work.

The linux-builder enables nested virtualization so the guest gets a real `/dev/kvm` and can run NixOS tests (`kvm` and `nixos-test` features). This needs an M3 or newer chip and macOS 15+; `nestedVirtualization` in the [host data](#host-data) turns nested virtualization and the `kvm`/`nixos-test` features off on older Macs. Only `aarch64-linux` guests are accelerated; `x86_64-linux` NixOS tests still fall back to slow emulation.

## Installation

1. Install Nix (with flakes support):

    ```bash
    sh <(curl -L https://nixos.org/nix/install)
    ```

1. Restart your shell and verify Nix:

    ```bash
    nix --version
    ```

1. Clone this repository and `cd` into it.

1. Create the [host data](#host-data) from the current user, host name, chip and repository path, then check it:

    ```bash
    just init-host <HOSTNAME>
    ```

1. Bootstrap `nix-darwin` from this flake (first activation). This runs `just init-host <HOSTNAME>` first if the host data does not exist yet:

```bash
just bootstrap <HOSTNAME>
```

## Host data

Machine identity is kept out of this repo, so a work machine's host name, user and private config are never committed. Each machine has `~/.config/nix-config-host/default.nix`:

```nix
{
  userName = "your-user";
  hostName = "YOUR-HOSTNAME"; # also the darwinConfigurations name
  repoRoot = "/Users/your-user/prog/nix-config";
  nestedVirtualization = true; # M3+ and macOS 15+
  # Private modules, e.g. work-only Zen containers or casks.
  darwinModules = [ ];
  homeModules = [ ./zen-work.nix ];
}
```

The flake reads it through its `host` input, which points at a stub that fails with an error. The `just` recipes pass the real directory with `--override-input host path:$HOME/.config/nix-config-host`. That flag implies `--no-write-lock-file`, so the path never ends up in `flake.lock`. Run raw `nix` or `darwin-rebuild` commands with the same flag.

Only that directory and the tracked files of this repo are copied into the Nix store. New files in this repo need `git add` before a build sees them.

Use the same value for `<HOSTNAME>` in the `just` recipes as `hostName`; it defaults to `hostname`.

The `just` recipes stop with a hint when the host data is missing. Until both machines have migrated, they instead create it from the old gitignored `local-config.nix`, `hardware.local.nix` and `zen-browser.local.nix` if those exist. The old files are left in place; delete them after a successful build.

## Validating and applying the configs

1. Validate

    ```bash
    just show
    just check
    just eval-system <HOSTNAME>
    just build-system <HOSTNAME>
    just build <HOSTNAME>
    ```

2. Apply manually when ready:

    ```bash
    just switch <HOSTNAME>
    ```

## Roll back to a previous version

If a newly applied system generation causes problems, you can roll back to an earlier nix-darwin generation. Because Home Manager is integrated as a nix-darwin module here, rolling back the system generation also rolls back the Home Manager state from that generation.

Roll back to the immediately previous generation:

```bash
just rollback
```

List available generations:

```bash
just generations
```

Roll back to a specific generation:

```bash
just rollback-to <GENERATION>
```

## Cleanup and garbage collection

```bash
# Delete all historical versions older than 7 days
just clean

# Wiping history won't garbage collect the unused packages, so run system gc manually as root:
just gc

# Due to the following issue, you need to run the gc command as per user to delete home-manager's historical data:
# https://github.com/NixOS/nix/issues/8508
just gc-user
```
