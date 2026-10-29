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

Tools of catalog servers are allowed without prompting (`permissions.nix`).
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
