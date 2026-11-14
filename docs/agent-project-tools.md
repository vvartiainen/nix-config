# Per-project MCP servers and skills

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

Claude Code keeps its global state in `~/.claude/.claude.json` through
`CLAUDE_CONFIG_DIR`. The managed `claude` launcher at `~/.local/bin/claude`
defaults this variable before running the Homebrew CLI, preserving explicit
overrides. GUI apps must use this launcher; invoking the Homebrew binary or
an app-bundled binary directly bypasses it. The first
switch moves `~/.claude.json` and its backups there; if a destination already
exists, resolve the conflicting files before switching again. Restart Claude
from a new terminal after switching.

GUI apps do not depend on a session-global launchd PATH. In T3 Code's provider
settings, set **Binary path** to the absolute path of `~/.local/bin/claude`
for Claude and `/etc/profiles/per-user/<user>/bin/pi` for sandboxed Pi.
Expand `~` and replace `<user>` with your local home/user name. Use
`~/.local/bin/pi-unsandboxed` only when intentionally giving T3's Pi sessions
access without Safehouse; T3's approval prompts are then the boundary.
See [T3's Pi setup](https://github.com/pingdotgg/t3code/blob/main/docs/user/providers-pi.md).

For Codex and Claude in T3 Code, choose **Auto-accept edits** to allow routine
workspace work while keeping sandbox escapes reviewed by you. Set the default
under **Settings → Threads → New threads → Permissions**, and change existing
threads separately. **Auto** uses automatic review; **Full access** removes the
ordinary approval boundary. T3 injects its own MCP endpoint and allows its Claude
tool namespace; do not register a global endpoint or grant shell access to its
local port to make those tools work. Tool-specific prompts in Codex remain
separate from shell approvals. See [T3 permission modes](https://github.com/pingdotgg/t3code/blob/main/docs/user/permission-modes.md).

Pi's approvals stay inside Safehouse. Use Codex or Claude for approved escapes,
or run blocked operations manually outside Pi. See [Pi's sandbox limits](agent-permissions.md#pi).

After first applying the removal of the old launchd environment settings,
reboot before testing GUI apps. Removing the Nix options does not clear values
already set in the running launchd session. Confirm provider discovery and
Claude's config directory again after reboot.

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
