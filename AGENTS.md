# nix-config

## Description

This repository contains my macOS configs using nix, nix-darwin and home-manager.

## Validation commands (no apply)

Choose validation according to the change:

- Run `just lint` for fast read-only checks on staged, unstaged and untracked
  files. Use `just lint --base <revision>` to include committed changes, or
  `just lint --all` to audit all owned files. Add `--format` for formatting
  checks; formatting is opt-in until the existing files have a consistent baseline.
- Documentation: review the diff and run `git diff --check`.
- Directly linked dotfiles and helper scripts: run relevant syntax or behavior
  checks and `git diff --check`; no system build is needed.
- Nix modules: run `statix check .`, fixture evaluation and `git diff --check`.
- Package, dependency, activation or build changes: also run a fixture system
  build. Build whenever evaluation leaves a concrete concern unresolved.

Codex, Claude and Copilot stop hooks run the same fast checks in this repository
and its worktrees after the user applies the hook configuration. They include
commits made since the current prompt, skip vendored code and never fix files,
evaluate Nix, build or apply. A failure asks the agent to address its changes
once; pre-existing issues and missing tools must be reported without changing
unrelated files. Hooks do not replace the scoped validation below or relevant
behavior tests. See [maintenance](docs/maintenance.md#repository-checks).

Use the tracked `nix/fixtures/host` input for Nix verification. Run commands
from the repository root. Do not run `just init-host` or migrate host data to
make validation work. For module evaluation without building:

```sh
statix check .
nix eval --raw '.#darwinConfigurations.agent-fixture.system.drvPath' \
  --override-input host "path:$PWD/nix/fixtures/host"
```

Evaluation checks module evaluation and derivation generation. It does not
build generated files or verify application behavior. Inspect relevant evaluated
options when checking generated configuration; use targeted application checks
for runtime behavior.

When a system build is required:

```sh
nix build --no-link '.#darwinConfigurations.agent-fixture.system' \
  --override-input host "path:$PWD/nix/fixtures/host"
```

The fixture contains only synthetic identity and paths, with nested
virtualization disabled and no private modules. Its `repoRoot` is a synthetic
path for generated dotfile links and does not need to exist. Never apply the
fixture system or change `flake.lock` for it. Do not read
`~/.config/nix-config-host` or request access to it for routine validation.
Pass the fixture override on every Nix invocation; it implies
`--no-write-lock-file`. Never commit real host names, usernames or
work-specific config to this repo. New files must be `git add`ed before Nix
evaluation or builds see them.

`nix flake show` is optional output inspection. `nix flake check` does not
validate `darwinConfigurations`; this flake currently exposes no `checks`.
Neither replaces an explicit system evaluation or build.

Host-specific `just` recipes use private host data and are for the user's manual
validation. Agents use `just lint` and the direct Nix commands above. Direct
`nix build --no-link` leaves no result symlink. Report that fixture verification
covers public configuration only; private modules, real identity and nested
virtualization require manual host validation.

Do not run apply commands (for example `just switch <hostName>` or
`darwin-rebuild switch`); user applies manually.

## Agent sandbox

Commands run in an OS sandbox (see
[sandbox usage](docs/agents/permissions.md#working-in-the-sandboxes)).

- Writable: the workspace, `$TMPDIR`, `/tmp`, and `~/.cache/<tool>-agent`;
  package caches already point there. Use `/tmp` for scratch files.
- Network: Codex allows ordinary internet access; other clients may restrict
  access to package download hosts and require approval for other domains.
- `nix build` and `nix fmt` require approval in Codex and Claude Code: builds
  run through the daemon outside the agent sandbox.
- Codex and Claude Code run routine project commands inside their sandboxes
  without prompts; Copilot requires normal approval for unlisted commands.
  Claude excludes `gh` and Rex from its sandbox; Rex requires approval.
  Reviewed sandbox escapes may run other commands outside it.
- `Operation not permitted`, `403`/`Forbidden`, or `x509: OSStatus -26276`
  mean the sandbox blocked it: retry once with escalation or ask, don't try
  variants or work around it.
- Credentials (`~/.ssh`, `~/.aws`, `.env`, keys) and tool installs
  (`mise install`) are off-limits; ask the user.
- Avoid interactive commands; pass non-interactive flags.

## Additional validation constraints

- Test direct Home Manager imports with small temporary consumer flakes pinned
  to this checkout and its existing inputs. Keep locks, results and generic users
  outside this repo.
- Do not rerun a permission-blocked formatter when the user has asked to skip
  formatting. Keep edits readable and run `git diff --check`.
- For helper scripts, check `type -a python3` and prefer an installed executable
  over a mise shim when it emits unrelated cache/state permission warnings.
  Do not change tool-manager permissions just to hide logs.

## Working conventions

- Prefer declarative configuration for everything
- Check existing documentation, also using MCP if such exists
- Keep module boundaries clear: one service per file in
  `nix/modules/nixos/services/`; host files only compose and set host facts.
- Keep changes minimal and easy to review
- Prefer updating existing modules/files over adding new abstractions
- Only update `flake.lock` when dependency updates are intentional
- `git commit` the changes you have made, but let user manually handle the push of the changes
  - use existing project commit style (conventional commits, short message, no long descriptions, no trailers such as Co-Authored-By or Claude-Session)
- At the end of implementation tasks summarize the changes:
  - What did you change
  - Was existing functionality affected
  - How the feature works on a higher level
  - If external dependencies were added or needed
  - If you deviated from some of our earlier decisions
- Also inform if you ran into some permission issues that could be fixed
- Clearly list any commands the user must run manually in the final response,
  using copyable code blocks with the required working directory and purpose.
  Distinguish remaining commands from commands already completed.
- Propose AGENTS.md improvements if you ran into permission issues and had to workaround them

## Documentation

- Keep repository documentation small: setup, everyday usage, required
  maintenance, agent instructions, and concise rationale needed to use or change
  the configuration correctly. Use clear categories by purpose.
- Keep agent-only guides focused on agents; put desktop, browser and terminal
  shortcuts in the general keybindings guide. Remove obsolete instructions and
  deprecated comparisons rather than preserving them as current guidance.
