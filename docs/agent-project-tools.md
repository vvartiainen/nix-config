# Per-project MCP servers and skills

MCP servers and skills are opt-in per project. Nix builds a catalog of
everything available; `ct agents` (cli-toolbox) records each project's choices
and generates the native files for Codex, Claude Code, OpenCode, Cursor,
Copilot and Pi. See cli-toolbox's
[agent tools guide](https://github.com/vvartiainen/cli-toolbox/blob/main/docs/agent-tools.md)
for choices, ownership and conflicts.

| Layer | Defined in | Reaches |
|---|---|---|
| Always on | `programs.mcp.servers` in `ai/mcp.nix` | Every project, through each CLI's global config |
| Catalog | `agents.mcpServers`, `agents.skillSources`, `agents.localSkills` and `ai/skills/` (`ai/agents-catalog.nix`) | `~/.config/cli-toolbox/agents/catalog.json` |
| Project choice | `.cli-toolbox/agents.json` (shared) or `agents.local.json` (personal) | That checkout only |

The catalog holds `nixos` and one `backlog-<name>` server per backlog, with
store-path commands. Project paths never enter this repository: choices live
in each project.

```sh
ct agents                              # pick choices interactively
ct tui                                 # Git › Agent tools: see state, toggle, sync
ct agents set mcp backlog-foo enable   # personal, git-excluded
ct agents set mcp nixos enable --shared
ct agents exclude enable               # keep generated files out of Git here
ct agents sync --dry-run && ct agents sync
```

Generated files contain store paths, so use `ct agents exclude enable` in
repositories where they should not be committed, including this one.

## Skill library

- Generic skills: add `nix/modules/home/programs/ai/skills/<name>/SKILL.md`.
- Private skills: set `agents.localSkills.<name> = <dir>;` in host data.
- Remote skills: add Rulesync sources to `agents.skillSources`, rebuild, then
  run `ct agents library install`.

Then enable them per project with `ct agents set skills <name> enable` and sync.
Servers dropped from `programs.mcp.servers` leave the global CLI configs on the
next activation.
