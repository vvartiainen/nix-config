# Agent configuration

## Select project tools

Nix supplies an MCP catalog; `ct agents` enables agents and MCP servers per
project and writes their (Git-ignored) project files. Review them before use.

```sh
ct agents set targets claude enable
ct agents set mcp nixos enable
ct agents sync --dry-run
ct agents sync
```

Codex and Pi load project servers after project trust. See the cli-toolbox
[agent tools guide](https://github.com/vvartiainen/cli-toolbox/blob/main/docs/agent-tools.md).

## Skills and plugins

Skills live in the private `agent-skills` repository and are installed with
Claude Code or Codex's marketplace commands; see its README. Nix does not
manage them. Rex's skill and hooks come with its CLI.

## Global cleanup

Close agent CLIs before switching and restart them afterwards. Every switch
removes global MCP registrations except the declared Rex and Herdr ones.

```sh
just cleanup-agent-config --dry-run
just cleanup-agent-config
```

Changed files are backed up under
`~/.local/state/nix-config/agent-config-backup/` (latest run only).

## T3 Code settings

Every switch merges the values declared in
[`t3-code.nix`](../../nix/modules/home/programs/ai/clients/t3-code.nix) into
`~/.t3/userdata/` settings and keybindings ([how](../design/t3-code.md)).
Declare a value in the module to keep it; changes made in the app are
overwritten. Close T3 before switching.

- Theme: Catppuccin Mocha is the default; bump `defaultThemeSetAt` to apply it
  again.
- Worktrees: T3 removes a thread's worktree when its linked pull requests
  merge, so agents link the pull request they open to the thread.
- Merge method: the default is **Rebase and merge**
  ([why](../design/t3-code.md#pull-request-merge-method)).

## Configuration validation

```sh
just validate-agent-config
```

Checks the installed global config files offline for structure and supported
values; `just check`, `just build` and activation also run it. It does not
check that commands, models or servers work, nor project settings or private
modules.
