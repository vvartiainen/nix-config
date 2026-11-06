# Per-project MCP servers and skills

## Select project tools

Nix supplies a catalog; `ct agents` selects agents, MCP servers and skills and
writes their project files. In this repository, generated agent configuration,
MCP registrations and skill copies are local and ignored by Git. Review generated
files before use; other projects can choose whether to commit their setup.
No catalog MCP server is enabled globally or started without a project entry.

```sh
ct agents set targets claude enable
ct agents set mcp nixos enable
ct agents sync --dry-run
ct agents sync
```

The catalog includes `nixos` and a `backlog-<name>` server for each configured
backlog. Backlog servers only work on machines where `bl` knows that backlog;
keep those registrations in your own projects. Codex and Pi load project
servers after project trust. Catalog server tools have configured permission
allowances. See the cli-toolbox
[agent tools guide](https://github.com/vvartiainen/cli-toolbox/blob/main/docs/agent-tools.md).

## Backlog shortcuts

Tasks and implementation documents live outside the repo. In a configured
project, including subdirectories and worktrees:

```sh
bl                        # tasks
bl review                 # needs-review queue
bl handoffs               # handoff + needs-review queue
bl board
bl browser
bl task TASK-73
```

Elsewhere, use an explicit project, such as `bl nix-config review`.
Selection prefers an explicit project, then detected repository/directory, then
`BACKLOG_PROJECT`. Repositories with different backlog names need an explicit
selection. `bl --help` shows wrapper help; `bl <project> --help` shows Backlog help.
The user accepts and completes review tickets; agents leave them open.

## Skill library

- Reusable skills: `nix/modules/home/programs/ai/skills/<name>/SKILL.md`.
- Private host guides: `agents.localSkills.<name> = <dir>;` in a private
  Home Manager module. Keep workstation-specific inventories there.
- Remote skills: `agents.skillSources`, then `ct agents library install` after
  rebuilding the catalog.

Enable a skill per project and review the generated files:

```sh
ct agents set skills review-before-push enable
ct agents sync --dry-run
ct agents sync
```

Start a new agent session to use it. Available workflow skills include
`backlog-task`, `work-on-task`, `rebase-main`, `review-before-push`, `handoff`
and `mac-disk-cleanup`; read their SKILL.md for scope. For an existing ticket,
invoke `work-on-task TASK-123`; `work-on-task prepare TASK-123` produces a brief
without starting implementation. Skills do not grant permissions. Skill files
enter the Nix store and project files, so keep credentials out.

## Global cleanup

Close agent CLIs before switching so they cannot write stale settings back.

Claude Code keeps its global state in `~/.claude/.claude.json` through
`CLAUDE_CONFIG_DIR`. The first switch moves `~/.claude.json` and its backups
there; if a destination already exists, resolve the conflicting files before
switching again. Restart Claude from a new terminal after switching.

Every switch removes global MCP registrations and undeclared global skills/
plugins, then restores declared Rex and Herdr integrations. Project tools,
authentication, session history and catalog/library remain in place.
Prefer project selection for other tools; manually enabled global tools are
removed again on the next switch.

```sh
just cleanup-agent-config --dry-run
just cleanup-agent-config
```

Review the dry run first. Manual cleanup also archives declared skills; switch
again to restore them. Changed files/directories are backed up under
`~/.local/state/nix-config/agent-config-backup/`; only the latest run that
changed something is retained. Inspect that private backup before recovery.
Custom CLI homes and administrator-managed tools are outside cleanup coverage.

## Configuration validation

```sh
just validate-agent-config
```

This builds the validator from the checkout and reads actual global config
files. `just check` and `just build` also invoke it; activation checks merged
settings. It reports schema coverage, parsing-only checks and missing files.
Validation is offline and checks structure and supported values, not whether
commands, models or servers work.

A failing merge preserves its destination and merge state, but activation is
not transactional: earlier successful steps may already have written files.
Project settings, custom CLI homes, private modules and runtime environment/
flag overrides are outside this check. Agents use only the public fixture;
the user validates private host settings manually before applying.

Catalog, cleanup, schema sources and merge details:
Backlog **doc-8 — Agent project tooling and configuration implementation**.
