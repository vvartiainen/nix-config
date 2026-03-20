# nix-config

## Description

This repository contains my macOS configs using nix, nix-darwin and home-manager.

## Directory structure

- `flake.nix` and `flake.lock`: flake entrypoint and pinned inputs
- `nix/darwin/`: nix-darwin modules and system-level configuration
- `nix/shared/`: shared modules that are not platform-specific
- `dotfiles/`: app config files (for example `nvim`, `tmux`, `yabai`, `skhd`)
- `scripts/`: small helper scripts used by the setup

## Validation commands (no apply)

Run these after config changes:

- `nix flake show`
- `nix flake check`
- `nix eval .#darwinConfigurations.<hostName>.system`
- `nix build .#darwinConfigurations.<hostName>.system`
- `darwin-rebuild build --flake .#<hostName>`

Do not run apply commands (for example `darwin-rebuild switch`); user applies manually.

## Working conventions

- Keep changes minimal and easy to review
- Prefer updating existing modules/files over adding new abstractions
- Only update `flake.lock` when dependency updates are intentional
