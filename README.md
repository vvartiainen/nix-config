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
- `nix/modules/darwin/`: macOS system modules (`homebrew`, `system-settings`) and macOS HM programs
  - `programs/`: macOS-specific Home Manager modules (`yabai`, `skhd`, `sketchybar`, `onepassword`)
- `dotfiles/`: actual config files for apps (`nvim`, `tmux`, `yabai`, `skhd`, etc.)
  - Using `mkOutOfStoreSymlink` so updates in these files are reflected directly
  - Might want to move some of these to "more pure" / immutable configs at some point

## Prerequisites

- macOS (Apple Silicon expected by current config)
- Xcode
- Homebrew
- just (`brew install just`)

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

1. Create local host overrides:

    ```bash
    cp ./local-config.nix.example ./local-config.nix
    ```

    Or generate it from the current user, host name, and repository path:

    ```bash
    just generate-local-config <HOSTNAME>
    ```

    Then edit `local-config.nix` and set or verify any values you want to override:

    - `userName`
    - `hostName`
    - `repoRoot`

    When using the gitignored `local-config.nix`, use `path:.#...` flake references so untracked local files are included.

    Use the same value for `<HOSTNAME>` as the `hostName` you set in `local-config.nix`.

1. Bootstrap `nix-darwin` from this flake (first activation). If `local-config.nix` does not exist yet, this command calls `just generate-local-config <HOSTNAME>` first:

```bash
just bootstrap <HOSTNAME>
```

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
