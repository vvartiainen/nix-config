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

## GUI providers

In T3 Code's provider settings, set **Binary path** to the absolute path of
`~/.local/bin/claude` for Claude and `/etc/profiles/per-user/<user>/bin/pi` for
sandboxed Pi. Expand `~` and replace `<user>` with your local home/user name.
The Claude launcher selects `~/.claude` through `CLAUDE_CONFIG_DIR`; app-bundled
or Homebrew binaries invoked directly bypass it.

Choose **Auto-accept edits** for Codex and Claude to keep sandbox escapes
reviewed by you. Set the default under **Settings → Threads → New threads →
Permissions**, and change existing threads separately. **Auto** uses automatic
review; **Full access** removes the ordinary approval boundary. T3 injects its
own MCP endpoint and allows its Claude tool namespace; Codex tool-specific
prompts remain separate from shell approvals. See [T3 permission modes](https://github.com/pingdotgg/t3code/blob/main/docs/user/permission-modes.md).

Sandboxed Pi cannot reach T3's local MCP endpoint or escape after approval.
Run blocked operations manually or use Codex/Claude; see [Pi's limits](permissions.md#pi).

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
