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
- `just eval-system`
- `just build-system`
- `just build`

Do not run apply commands (for example `just switch <hostName>`); user applies manually.

The hostname is selected automatically, you should only need `just build` without anything else.

## Working conventions

- Keep module boundaries clear: when creating program specific zsh config for example, add it to the program module instead of the generic zsh.nix
- Keep changes minimal and easy to review
- Prefer updating existing modules/files over adding new abstractions
- Only update `flake.lock` when dependency updates are intentional
- `git commit` the changes you have made, but let user manually handle the push of the changes
  - use existing project commit style (conventional commits, short message, no long descriptions, no co-authored ads)
