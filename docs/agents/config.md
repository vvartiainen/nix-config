# Agent configuration

## Select project tools

Nix supplies an MCP catalog; `ct agents` selects agents and MCP servers per
project and writes their project files. In this repository those generated
files are local and ignored by Git; review them before use. No catalog MCP
server is enabled globally.

```sh
ct agents set targets claude enable
ct agents set mcp nixos enable
ct agents sync --dry-run
ct agents sync
```

Codex and Pi load project servers after project trust. Tool approval depends on
the client: some adapters allow catalog tools, while Pi's MCP tools still ask.
Loading a server does not let its process escape the sandbox. See the
cli-toolbox
[agent tools guide](https://github.com/vvartiainen/cli-toolbox/blob/main/docs/agent-tools.md).

## Skills and plugins

Authored skills live in the private `agent-skills` repository and are installed
through Claude Code or Codex's native marketplace commands; its README covers
installation, updates and development. Nix does not manage skill sources or
marketplace choices. Rex's bootstrap skill and hooks come with its pinned CLI.
Skills and plugins grant no permissions.

## Global cleanup

Close agent CLIs before switching so they cannot write stale settings back, and
restart them afterwards.

Every switch removes global MCP registrations, then restores the declared Rex
and Herdr integrations; manually enabled global servers do not survive.
Skills, plugins, marketplace choices, project tools, authentication and session
history stay.

```sh
just cleanup-agent-config --dry-run
just cleanup-agent-config
```

Review the dry run first. Changed files are backed up under
`~/.local/state/nix-config/agent-config-backup/`, keeping only the latest run
that changed something. Custom CLI homes and administrator-managed tools are
not covered.

## T3 Code settings

The Homebrew cask provides the app. Every switch merges the values declared in
[`t3-code.nix`](../../nix/modules/home/programs/ai/clients/t3-code.nix) into
`settings.json`, `client-settings.json` and `keybindings.json` under
`~/.t3/userdata/`, keeping other app-managed values
([how](../design/t3-code.md)). To keep a change made in T3, declare it in the
module; declared values are restored on each switch. Close T3 before switching
and reopen it afterwards.

The module also publishes the Catppuccin Mocha theme as the default. Each
client adopts it once and keeps a later choice; bump `defaultThemeSetAt` to
apply it again.

Worktrees are cleaned up when every linked pull request merges, on thread
deletion or when unchanged, subject to T3's local-change protection. Merge
cleanup needs a linked pull request, so agents link the pull request they open
to their thread; a plain `git merge` leaves the worktree in place. Idle cleanup
and retention stay app-managed under **Settings → Worktrees → Cleanup**.

### Pull request merge method

The environment default is **Rebase and merge**, matching the rebase-only
repositories; see [why it is declared](../design/t3-code.md#pull-request-merge-method).
Settings → Source control → **Default pull request merge method** shows the
effective value; a per-project override set there stays app-owned and wins.

## Configuration validation

```sh
just validate-agent-config
```

This builds the validator from the checkout and reads the installed global
config files; `just check` and `just build` also run it, and activation checks
merged settings. It reports schema coverage, parsing-only checks and missing
files. Validation is offline and checks structure and supported values, not
whether commands, models or servers work.

A failing merge preserves its destination, but activation is not
transactional: earlier steps may already have written files. Project settings,
custom CLI homes, private modules and runtime overrides are outside this check.
Agents use only the public fixture; the user validates private host settings
before applying.
