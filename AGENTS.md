# nix-config

## Description

This repository contains my macOS configs using nix, nix-darwin and home-manager.

## Directory structure

- `flake.nix` and `flake.lock`: flake entrypoint and pinned inputs
- `nix/hosts/`: per-host composition roots (currently `mbp`)
- `nix/modules/shared/`: system-level modules that are not platform-specific
- `nix/modules/home/`: Home Manager user base and per-program modules
- `nix/modules/darwin/`: macOS system modules and macOS-specific Home Manager programs
- `dotfiles/`: app config files (for example `nvim`, `tmux`, `yabai`, `skhd`)

## Validation commands (no apply)

Use the `justfile` recipes after config changes so commands get the repository's
correct bootstrapping:

- `just show`
- `just check`
- `just eval-system <hostName>`
- `just build-system <hostName>`
- `just build <hostName>`

Do not run apply commands (for example `just switch <hostName>`); user applies manually.

## Working conventions

- Keep changes minimal and easy to review
- Prefer updating existing modules/files over adding new abstractions
- Only update `flake.lock` when dependency updates are intentional
