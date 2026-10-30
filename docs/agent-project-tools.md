# Per-project MCP servers and skills

MCP servers and skills live in each project's own agent files, committed with
it. Nix installs the server commands on `PATH` and builds a catalog of
everything available; `ct agents` (cli-toolbox) picks the project's agents,
servers and skills from it and writes each agent's project files. Nothing is
configured globally and no server runs unless a project's files list it. See
cli-toolbox's
[agent tools guide](https://github.com/vvartiainen/cli-toolbox/blob/main/docs/agent-tools.md).

| Layer | Defined in | Reaches |
|---|---|---|
| Catalog | `agents.mcpServers`, `agents.skillSources`, `agents.localSkills` and `ai/skills/` (`ai/agents-catalog.nix`) | `~/.config/cli-toolbox/agents/catalog.json` |
| Project | `ct agents` or `ct tui` › Git › Agent tools | The project's committed agent files |

The catalog holds `nixos` (`mcp-nixos`) and one `backlog-<name>` server per
backlog (`bl <name> mcp start`); both commands are on `PATH`, so the committed
files contain no machine paths. Backlog servers only work where `bl` knows the
backlog, so commit them only in your own projects.

```sh
ct agents set targets claude enable    # every agent is off until chosen
ct agents set mcp nixos enable
ct agents sync --dry-run && ct agents sync
```

Tools of catalog servers are allowed without prompting: `permissions.nix`
exposes the catalog server names, and each CLI module renders its tool rules.
Codex and Pi read project servers once you trust the project.

## Backlog shortcuts

`bl` selects an external backlog from `backlog.projects`; it does not create
task files in the current repository. Inside a configured project's repository,
including subdirectories and linked worktrees, omit the project name:

```sh
bl                         # task list
bl review                  # all tickets tagged needs-review
bl handoffs                # tickets tagged both handoff and needs-review
bl review --plain          # list options pass through
bl board                   # terminal board
bl browser                 # browser interface
bl task TASK-73             # open a ticket
```

Selection order is an explicit configured project name, the detected project,
then `BACKLOG_PROJECT`. Detection matches the main checkout's directory name
against `backlog.projects`, including when run from a linked worktree, then
tries the current Git root's name. Outside Git, it uses the nearest ancestor
directory whose name is a configured project. An unrelated Git repository does
not inherit a matching parent directory's backlog. Unknown environment defaults
are rejected.

From elsewhere, use `bl nix-config review` or `bl cli-toolbox browser` if those
projects are configured. Repositories whose names differ from their backlogs
also need an explicit name or `BACKLOG_PROJECT`. `bl --help` shows wrapper help;
`bl <project> --help` shows Backlog.md help. Other arguments pass through to
Backlog.md, including the explicit `bl <project> mcp start` used by agents.

The handoff queue is for user review. Agents leave these tasks open; the user
checks the review criteria, removes `needs-review`, and marks accepted work Done.

## Skill library

- Generic skills: add `nix/modules/home/programs/ai/skills/<name>/SKILL.md`.
- Private skills: set `agents.localSkills.<name> = <dir>;` in host data.
- Remote skills: add Rulesync sources to `agents.skillSources`, rebuild, then
  run `ct agents library install`.

Then turn them on per project with `ct agents set skills <name> enable` and
sync; their files are copied into the project.

The reusable workflow skills in this repo are:

| Skill | Use |
| --- | --- |
| `review-before-push` | Review outgoing commits and working changes for secrets and internal material; request a full-history audit explicitly. Reports redacted findings and coverage gaps. |
| `rebase-main` | Rebase a feature branch onto main with a recovery ref, conflict review and verification of linear history. |
| `handoff` | Summarize changes, commits, permission issues, spec deviations, backlog activity, verification, manual checks and remaining risks. |
| `backlog-task` | Capture a task with a short title, why and observable acceptance criteria; search for duplicates and follow the project's workflow. |
| `work-on-task` | Give an agent work by task ID or title; resolve scope, dependencies and ownership, execute and hand off, or prepare a brief for another agent. |

Publication reviews honor an explicit local comparison base without fetching.
For remote refs, `review-before-push` prefers anonymous HTTPS for public repos
and existing `gh` authentication for private GitHub repos, using one-off fetches
that preserve remote settings. It explains verified SSH requirements and
distinguishes them from authentication or sandbox access failures.

For example, after the user rebuilds/applies the catalog, select a skill in the
target project and review the generated files:

```sh
ct agents set skills review-before-push enable
ct agents sync --dry-run
ct agents sync
```

Select the other skills by name in the same way, then invoke them in a new agent
session. Creating the library does not enable skills in projects automatically.
The skills follow each project's instructions and backlog policy. Reviewing
does not publish or rewrite commits; rebasing does not push. A useful finishing
sequence is rebase, required checks, review the resulting outgoing history,
then handoff. Run task creation whenever new work needs capturing.

To give an already running agent a task, enable `work-on-task` in that project
and invoke it with `work-on-task TASK-123` or `work-on-task "Exact task title"`.
The agent resolves the current task, records its plan, implements and verifies
it, then leaves the required review handoff. `work-on-task prepare TASK-123`
produces a copyable brief without starting work or claiming the task.

The skill includes an agent-sandbox integration section with the shared MCP
entry shapes verified from `ai/mcp.nix`. Its provisioning/launch contract is a
fill-in template: the sibling sandbox source was inaccessible during authoring,
so no VM launch command, mount layout or skill delivery is assumed. Fill this
section from your sandbox's documentation before using it for automatic launch.

## Global cleanup

Every switch runs `cleanup-agent-config` before merging the CLI settings.
It can also be run manually after the first switch that installs it:

```sh
just cleanup-agent-config --dry-run
just cleanup-agent-config
```

Close the agent CLIs before switching or cleaning, then restart them so they
load the updated settings. An open CLI can write its old settings back.

The script removes user-level MCP registrations from Codex (including profiles),
Claude Code, Copilot, Cursor, Pi, and OpenCode. It disables global Codex and
Claude plugins, clears Copilot's installed-plugin registry and disables its
declarative plugin choices, and removes OpenCode's global plugin and extra
skill-path settings. It archives
loose skills from `~/.agents/skills`, `~/.codex/skills` (except `.system`),
`~/.claude/skills`, `~/.copilot/skills`, `~/.cursor/skills`, `~/.pi/agent/skills`,
and `~/.config/opencode/skills`, plus Claude's global commands, Pi's loose
extensions, and OpenCode's global plugins. Herdr's `herdr-agent-state`
extension and plugin stay, since they only report agent state. XDG config and state directories
are respected. This covers the default CLI locations managed by this repo;
custom CLI home directories and administrator-managed tools need separate handling.

Changed files and archived directories are backed up under
`~/.local/state/nix-config/agent-config-backup/`, with the original absolute
path mirrored inside. Only the latest run that changed something is kept. Config backups are private. Symlinked skill
directories are archived as links, leaving their targets intact. A repeat run
with no new global tools makes no changes. Invalid config files stop cleanup
before any config is changed.

Project files, authentication, session history, plugin caches and the `ct agents`
catalog/library remain in place. Pi's Nix-declared packages remain enabled.
Codex's cached `.system` skills stay on disk but are disabled in Nix; disabled
skills can remain visible in `/skills` as disabled entries. Cursor recreates
its `skills-cursor` built-ins and has no supported setting to disable them.

## Configuration validation

Check global agent configuration without modifying it:

```sh
just validate-agent-config
```

The recipe builds and runs the validator from this checkout, so it works before
the first switch. It uses the synthetic host input only to build the helper;
the helper reads your actual global config files. Activation also installs a
`validate-agent-config` command for direct use.

`just check` and `just build` also check the installed files. Nix builds check
the generated Home Manager files and schema-backed merge settings. During
activation, cleanup validates every transformed candidate before its first
write, each merge validates its complete candidate before replacing the config
or merge state, and a final validation runs after all agent merges. Manual
`just cleanup-agent-config` runs the final check too. Validation failure exits
nonzero; the failing merge leaves its destination and state unchanged. This is
not a transaction across all activation steps: earlier successful merges can
already have been written when a later merge fails.

| Configuration | Validation |
| --- | --- |
| Codex `config.toml` | Upstream schema from `rust-v0.166.0`, matching the Homebrew CLI used here |
| Claude Code `settings.json` | Pinned SchemaStore Claude Code settings schema |
| OpenCode runtime and v2 CLI settings | Schemas from the pinned nixpkgs OpenCode package |
| OpenCode legacy `tui.json` | Published TUI schema, pinned by content hash |
| Pi settings, keybindings, models and the declared theme | Schemas shipped with the pinned Pi package |
| Cursor, Copilot, MCP registries, Claude runtime state and desktop config | Parsing and object-root checks only; no schema bundled |

The command reports the schema used for each existing file, labels limited
coverage as `parse only; no schema`, and reports missing files explicitly.
OpenCode's mutable global files and Home Manager layers are checked separately
and together. JSONC is accepted for Copilot `settings.json`, its auto-managed
`config.json` (including the generated comment header), and OpenCode files.
TOML is parsed before Codex schema validation. Unknown keys are rejected only
where the upstream schema rejects them; permissive schemas cannot catch every typo.

Schemas are bundled through
[`agent-config-validation.nix`](../nix/modules/home/agent-config-validation.nix).
Validation itself requires no network and does not follow a config's `$schema`
URL. Update schema versions/hashes deliberately when upgrading CLIs; the legacy
TUI URL can require a hash refresh if upstream replaces it. The regression
tests run as part of building the validator package.

Coverage follows this repo's default global CLI paths and XDG config directory.
Project settings, custom CLI home overrides, private modules, environment/flag
overrides, runtime permissions and credentials are outside this check. A
successful schema check verifies structure and supported values, not whether a
command, model, path or server works. Close running CLIs before switching or
cleaning to keep them from writing stale settings back. Agents validate only
the synthetic public fixture; validate the private host manually before apply.
