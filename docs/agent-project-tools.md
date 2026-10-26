# Per-project MCP servers and skills

MCP servers and skills are opt-in per project. Nix builds a catalog of
everything available; `ct agents` (cli-toolbox) records which ones each
checkout uses, outside the checkout, and the agent commands start through
`ct agents launch`, which hands them over as launch options. Nothing is written
to the projects or to the agents' global configs, and what a project commits
for its agents keeps working alongside. See cli-toolbox's
[agent tools guide](https://github.com/vvartiainen/cli-toolbox/blob/main/docs/agent-tools.md).

| Layer | Defined in | Reaches |
|---|---|---|
| Always on | `programs.mcp.servers` in `ai/mcp.nix` | Every project, through each CLI's global config |
| Catalog | `agents.mcpServers`, `agents.skillSources`, `agents.localSkills` and `ai/skills/` (`ai/agents-catalog.nix`) | `~/.config/cli-toolbox/agents/catalog.json` |
| Project choice | `ct agents` or `ct tui` › Git › Agent tools | That checkout, via `~/.local/state/cli-toolbox/agents/` |

The catalog holds `nixos` and one `backlog-<name>` server per backlog, with
store-path commands.

```sh
ct agents                              # toggle choices interactively
ct agents set mcp backlog-foo enable
ct agents status
```

The `claude`, `codex`, `copilot` and `pi` zsh functions start the agent through
`ct agents launch`:

| Agent | MCP servers | Skills |
|---|---|---|
| Claude Code | yes (`ct-agents` plugin) | yes (`ct-agents:<skill>`) |
| Codex | yes (`-c`) | no |
| Copilot | yes | yes |
| Pi | no | yes |
| OpenCode, Cursor | no | no |

Tools of catalog servers are allowed without prompting (`permissions.nix`); in
Claude Code they are named `mcp__plugin_ct-agents_<server>__<tool>`.

## Skill library

- Generic skills: add `nix/modules/home/programs/ai/skills/<name>/SKILL.md`.
- Private skills: set `agents.localSkills.<name> = <dir>;` in host data.
- Remote skills: add Rulesync sources to `agents.skillSources`, rebuild, then
  run `ct agents library install`.

Then turn them on per project with `ct agents set skills <name> enable`.
Servers dropped from `programs.mcp.servers` leave the global CLI configs on the
next activation.
