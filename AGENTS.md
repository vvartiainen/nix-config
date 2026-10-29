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

Prefer direct Nix commands for agent verification after config changes. Run
linting and one system build from the repository root:

```sh
statix check .
nix build --no-link '.#darwinConfigurations.<hostName>.system' \
  --override-input host 'path:<host-directory>'
```

Replace `<host-directory>` with the absolute path to `~/.config/nix-config-host`
and `<hostName>` with its `hostName` value (see README "Host data"). Pass the
host override on every Nix invocation; it implies `--no-write-lock-file`.
Never commit host names, usernames or work-specific config to this repo. New
files must be `git add`ed before a build sees them.

For a quick evaluation without building, use:

```sh
nix eval --raw '.#darwinConfigurations.<hostName>.system.drvPath' \
  --override-input host 'path:<host-directory>'
```

`nix flake show` is optional output inspection. `nix flake check` does not
validate `darwinConfigurations`; this flake currently exposes no `checks`.
Neither replaces an explicit system evaluation or build.

The `just` recipes remain available for convenience. `just build-system` and
`just build` build the same system package; running both is redundant. Direct
`nix build` avoids the `darwin-rebuild` dependency and leaves no result symlink
when passed `--no-link`.

Do not run apply commands (for example `just switch <hostName>` or
`darwin-rebuild switch`); user applies manually. Documentation-only changes
need a diff review and `git diff --check`, not a system build.

## Agent sandbox

Commands run in an OS sandbox (see `docs/agent-permissions.md`, "Working in
the sandboxes").

- Writable: the workspace, `$TMPDIR`, and `~/.cache/<tool>-agent`; package
  caches already point there. Use `$TMPDIR` for scratch files.
- Network: package download hosts only; other hosts need approval. Fetching
  flake inputs from GitHub may need `github.com` approved.
- `just` and `nix build` require command approval under the shared permission
  rules. Direct Nix evaluation avoids the `just` wrapper prompt; builds still
  run through the daemon outside the agent sandbox and require approval.
- `Operation not permitted`, `403`/`Forbidden`, or `x509: OSStatus -26276`
  mean the sandbox blocked it: retry once with escalation or ask, don't try
  variants or work around it.
- Credentials (`~/.ssh`, `~/.aws`, `.env`, keys) and tool installs
  (`mise install`) are off-limits; ask the user.
- Avoid interactive commands; pass non-interactive flags.

## Validation in a restricted agent session

- Try direct Nix verification with the real host input first. A missing-file
  result for private host data can mean the session cannot read it; request
  access before falling back to a fixture. Do not run `just init-host` or
  migrate host files just to get validation working.
- If real host data remains unavailable after requesting access, create a
  temporary directory outside the repo with a minimal `default.nix`: generic
  `userName`/`hostName`, this checkout's `repoRoot`, and
  `nestedVirtualization = false`. No private modules or real machine identity
  belong in that fixture or in committed files.
- Use the same direct Nix commands with the fixture's `hostName` and
  `--override-input host 'path:<temporary-directory>'`. Resolve the temporary
  directory with `realpath` first; Nix path inputs can reject macOS symlink
  prefixes such as `/var`. Report that the result validates the public
  configuration with a fixture, not the real machine's private configuration.
  Do not change `flake.lock` for the fixture.
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
