# Agent configuration

## Select project tools

Nix supplies an MCP catalog; `ct agents` selects agents and MCP servers and
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

The catalog includes the `nixos` server. Codex and Pi load project servers
after project trust. Tool approval depends on the client: some adapters allow
catalog tools, while Pi's MCP tools still ask. Loading a server does not grant
its process an escape from the sandbox.
See the cli-toolbox
[agent tools guide](https://github.com/vvartiainen/cli-toolbox/blob/main/docs/agent-tools.md).

## Skills and plugins

Authored skills live in the private `agent-skills` repository and are installed
through Claude Code or Codex's native marketplace commands. Its README covers
installation, updates and development. Nix does not copy skills into the store,
register skill sources or reset marketplace choices on activation. Sandboxed
commands can read the clients' plugin caches to run packaged skill helpers.

Rex's vendor bootstrap skill and hooks remain managed with its pinned CLI.
Skills and plugins do not grant permissions; the active session policy applies.

## Global cleanup

Close agent CLIs before switching so they cannot write stale settings back.
Restart them afterwards to load the new configuration.

Every switch removes global MCP registrations, then restores declared Rex and
Herdr integrations. Skills, plugins, marketplace choices, project tools,
authentication and session history remain in place. Select MCP servers per
project; manually enabled global MCP servers are removed on the next switch.

```sh
just cleanup-agent-config --dry-run
just cleanup-agent-config
```

Review the dry run first. Changed configuration files are backed up under
`~/.local/state/nix-config/agent-config-backup/`; only the latest run that
changed something is retained. Inspect that private backup before recovery.
Custom CLI homes and administrator-managed tools are outside cleanup coverage.

## T3 Code settings

The Homebrew cask provides the app. Nix merges provider paths, the default
[permission mode](permissions.md#t3-code-permission-modes) and these cleanup
settings into `~/.t3/userdata/settings.json` on every switch:

| Setting | Value | Effect |
| --- | --- | --- |
| `sidebarAutoSettleOnMerge` | `true` | Settle a thread after every pull request linked to it merges |
| `storageCleanup.worktreeOnMerge` | `true` | Remove its worktree once those commits are in the remote default branch |

Merge cleanup needs a linked pull request, so create the pull request from T3
Code or with `gh pr create`; a plain `git merge` leaves the worktree in place.
The server watches the file, so no restart is needed after a switch.

Everything else in that file stays app-managed. Cleanup for idle, settled,
unchanged and deleted-thread worktrees, plus browser capture and log retention,
stays off until enabled under **Settings → Worktrees → Cleanup**. Provider
switches, forks and delegated tasks hand off conversation context on their own;
see [portable handoffs](https://github.com/pingdotgg/t3code/blob/main/docs/user/portable-handoffs.md).

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
