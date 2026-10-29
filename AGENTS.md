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

Use the tracked `nix/fixtures/host` input for agent verification after config
changes. Run linting and one system build from the repository root:

```sh
statix check .
nix build --no-link '.#darwinConfigurations.agent-fixture.system' \
  --override-input host "path:$PWD/nix/fixtures/host"
```

The fixture contains only synthetic identity and paths, with nested
virtualization disabled and no private modules. Do not read
`~/.config/nix-config-host` or request access to it for routine validation.
Pass the fixture override on every Nix invocation; it implies
`--no-write-lock-file`. Never commit real host names, usernames or
work-specific config to this repo. New files must be `git add`ed before a
build sees them.

For a quick evaluation without building, use:

```sh
nix eval --raw '.#darwinConfigurations.agent-fixture.system.drvPath' \
  --override-input host "path:$PWD/nix/fixtures/host"
```

`nix flake show` is optional output inspection. `nix flake check` does not
validate `darwinConfigurations`; this flake currently exposes no `checks`.
Neither replaces an explicit system evaluation or build.

The `just` recipes use private host data and are for the user's manual
validation. Agents use the direct commands above. Direct `nix build --no-link`
avoids the `just` approval prompt and leaves no result symlink.

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
- Codex, Claude Code, and Copilot run `npm test` and `cargo test` without
  blanket command prompts under their configured sandboxes. Codex and Copilot
  also allow `terraform validate`; Claude still prompts because Terraform is
  excluded from its sandbox for macOS TLS compatibility. `npm run`, `npx`, and
  `nix fmt` still prompt; `nix fmt` can build its formatter through the daemon.
  Copilot also narrowly allows the installed `nixfmt` formatter.
- `Operation not permitted`, `403`/`Forbidden`, or `x509: OSStatus -26276`
  mean the sandbox blocked it: retry once with escalation or ask, don't try
  variants or work around it.
- Credentials (`~/.ssh`, `~/.aws`, `.env`, keys) and tool installs
  (`mise install`) are off-limits; ask the user.
- Avoid interactive commands; pass non-interactive flags.

## Validation in a restricted agent session

- Use `nix/fixtures/host` directly; no private host input or temporary host
  directory is needed. Do not run `just init-host` or migrate host files just
  to get validation working.
- Report that fixture validation covers the public configuration only. It
  does not validate private modules, real machine identity or nested
  virtualization. The fixture's `repoRoot` is a synthetic path for generated
  dotfile links; it does not need to exist. Never apply the fixture system.
  Do not change `flake.lock` for the fixture.
- Use small temporary consumer flakes for testing direct Home Manager imports
  on Linux or macOS. Pin their inputs to this checkout and its existing inputs;
  keep temporary locks, results and generic users outside this repo.
- The user validates their private host configuration manually before
  applying it. Fixture validation does not require wider filesystem access;
  normal build and network approval rules still apply.
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
- Before creating or changing tasks, read `doc-4`, "Agent handoff and review
  workflow", using `document_view` on `backlog-nix-config`. Follow its review
  queue, user acceptance, and end-of-session handoff rules alongside the
  built-in workflow guides.
- Create or update a session handoff task tagged `handoff` and `needs-review`
  after changing tasks or repository files, as described in `doc-4`. The user
  completes review tasks; do not maintain `doc-2` as a session handoff.
