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
| Always on | `programs.mcp.servers` in `ai/mcp.nix` (empty) | Every project, through each CLI's global config |
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

## Skill library

- Generic skills: add `nix/modules/home/programs/ai/skills/<name>/SKILL.md`.
- Private skills: set `agents.localSkills.<name> = <dir>;` in host data.
- Remote skills: add Rulesync sources to `agents.skillSources`, rebuild, then
  run `ct agents library install`.

Then turn them on per project with `ct agents set skills <name> enable` and
sync; their files are copied into the project.
