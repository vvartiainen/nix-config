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

Host identity comes from `~/.config/nix-config-host` through the `host` flake input (see README "Host data"). Never commit host names, usernames or work-specific config to this repo. New files must be `git add`ed before a build sees them.

## Validation in a restricted agent session

- Try the normal `just` recipes first. A missing-file result for private host
  data can mean the session cannot read it; do not run `just init-host` or
  migrate host files just to get validation working.
- If real host data remains unavailable after requesting access, create a
  temporary directory outside the repo with a minimal `default.nix`: generic
  `userName`/`hostName`, this checkout's `repoRoot`, and
  `nestedVirtualization = false`. No private modules or real machine identity
  belong in that fixture or in committed files.
- Run the same recipes with
  `just --set host_dir <temporary-directory> --set host <fixture-hostName> <recipe>`.
  This preserves the repository's host override/bootstrap logic. Report that
  the result validates the public configuration with a fixture, not the real
  machine's private configuration. Do not change `flake.lock` for the fixture.
- If `darwin-rebuild` is missing from PATH, check the installed command at
  `/nix/var/nix/profiles/system/sw/bin/darwin-rebuild`. Add its resolved store
  directory to PATH for `just build`; do not fetch an unrelated nix-darwin
  version. `just build-system` also builds the system derivation directly.
- Use small temporary consumer flakes for testing direct Home Manager imports
  on Linux or macOS. Pin their inputs to this checkout and its existing inputs;
  keep temporary locks, results and generic users outside this repo.
- Temporary fixtures support evaluation/build testing. They do not grant
  access to restricted private files or replace actual host validation.
  Request access when needed and clearly report any remaining limitation.
- Do not rerun a permission-blocked formatter when the user has asked to skip
  formatting. Keep edits readable and run `git diff --check`.
- For helper scripts, check `type -a python3` and prefer an already-installed
  Python executable over a mise shim when it emits unrelated cache/state
  permission warnings. Do not change tool-manager permissions just to hide logs.

## Working conventions

- Check existing documentation, also using MCP if such exists
- Keep module boundaries clear: when creating program specific zsh config for example, add it to the program module instead of the generic zsh.nix
- Keep changes minimal and easy to review
- Prefer updating existing modules/files over adding new abstractions
- Only update `flake.lock` when dependency updates are intentional
- `git commit` the changes you have made, but let user manually handle the push of the changes
  - use existing project commit style (conventional commits, short message, no long descriptions, no trailers such as Co-Authored-By or Claude-Session)
- Update existing documentation, also using MCP if such exists

## Backlog

Ideas and open work are tracked in a Backlog.md backlog through the `backlog-nix-config` MCP server, not in the repo.

- Read `backlog://workflow/overview` or call `get_backlog_instructions` first
- Search for an existing task before creating one
- Keep the task status and notes current while working
