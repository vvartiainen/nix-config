# Agent CLI permissions

Command rules, fetch domains, sandbox paths, and agent caches are defined once
in `nix/modules/home/programs/ai/permissions.nix`, grouped under `commands`,
`paths`, `network`, and `caches` in its `let` bindings. Each CLI module imports
the policy with `lib` and `config`, renders its native permission format in
local bindings, and adds its own sandbox and approval settings. The shared
module also exposes the catalog's `mcpServers` names.

The model follows Codex: **the sandbox is the boundary, and prompts are for
leaving it.** Routine commands and workspace edits run without approval inside
an OS sandbox. Prompts are reserved for commands that need extra review and
for anything that has to run outside the sandbox.

## Approval behavior

| CLI | Sandboxed commands | File edits | Still prompts |
|---|---|---|---|
| Codex | Run without approval (`on-request`) | Auto-applied in the workspace | Ask rules, sandbox escapes |
| Claude | Run without approval (`autoAllowBashIfSandboxed`) | Auto-accepted in the workspace (`acceptEdits`) | Ask rules, sandbox escapes, unlisted hosts |
| Cursor | Run without approval (`Run in Sandbox`) | CLI default | Sandbox escapes |
| Copilot | Shared safe command allowlist | Prompted | Unlisted commands, sandbox bypasses, unlisted hosts, file edits |
| OpenCode | No sandbox; `*` is ask | CLI default | Everything not allowlisted |
| Pi | No permission config | — | — |

Copilot has no "approve if sandboxed" setting or per-command ask override.
It allows only the shared `commands.allowed` prefixes and `commands.exact`
entries, plus configured MCP servers. Other commands, including Rex control
and arbitrary project runners, need normal approval; deny rules still win.
The allowlist applies outside the sandbox too. Keep sandboxing enabled.
Its sandbox network is limited to `network.sandbox`, with local-network access
explicitly disabled so localhost is not added to the allowlist.
OpenCode has no OS sandbox, so its
rules are the only boundary. Pi has neither; anything it runs uses the user's
normal access.

## Shared lists

These policy values live in `permissions.nix`. Paths and caches are resolved
from the importing Home Manager configuration.

| List | Purpose |
|---|---|
| `commands.allowed` | Read-only prefixes (`git status`, `nix eval`, `gh pr view`, `terraform fmt`, …) allowed everywhere, including outside a sandbox |
| `commands.exact` | Allowed only as written (`git branch --show-current`); their prefixes would allow destructive forms |
| `commands.sandboxAsk` | Commands that delegate work outside the agent sandbox: `nix fmt`, `nix build`, and Rex through PATH, profile links, its pinned Nix package and standard app bundles; prompt in Codex and Claude |
| `commands.routine` | Project-code runners and wrappers (`just`, `npm run`, `npx`, `npm test`, `cargo test`, `terraform validate`); sandbox approval everywhere except Claude Terraform, ask in OpenCode |
| `commands.denied` | Never auto-approved (`op`, `security`, `gh auth`, `gh api`, `sudo`, `darwin-rebuild`, `just switch`, `git push --force`, `mise trust`) |
| `paths.homeReadable` | Home paths sandboxed commands may read (`.agents` for shared skills, `.config`, `.local/share`, `.local/state`, `.cache`, shell startup files, Nix profiles, toolchains); the rest of `~` is denied |
| `paths.readable` | `paths.homeReadable` as absolute paths |
| `paths.homeSecrets` | Credential paths under `~` denied for reads, also inside `paths.homeReadable` (`.ssh`, `.aws`, `.docker`, `.config/gh`, `.config/op`, agent auth and state, shell secrets, …) |
| `paths.secretFiles` | Key files denied everywhere (`**/*.pem`, `**/*.key`); `.env` files are denied per CLI |
| `paths.denied` | `paths.homeSecrets` as plain absolute paths, for sandboxes that don't take globs |
| `network.fetch` | Docs and registry sites the web-fetch tools may read |
| `network.sandbox` | Download-only hosts sandboxed commands may reach (Nix registry, PyPI, crates index, Go module proxy and checksum DB, mise version index, SchemaStore). Upload-capable registries (`registry.npmjs.org`, `crates.io`, `api.github.com`) are excluded |
| `paths.readonly` | Tool paths outside the sandboxes' built-in grants (`/nix/store`, Homebrew, mise data and config, aube store, git config) |
| `paths.runtime` | Paths git and Nix probe at startup (`~/.gitconfig`, Nix profile symlinks, `/etc/nix`), for sandboxes that deny reads outside their grants |
| `paths.tmp` | `/tmp` (and `/private/tmp`), writable in every sandbox so agents can use literal temp paths |
| `paths.nixDaemonSocket` | The Nix daemon socket sandboxed `nix` commands connect to |
| `caches` | Separate writable package manager caches (`writePaths`) and the env vars pointing tools at them (`env`) |
| `mcpServers` | Catalog MCP servers (`mcp.nix`) whose tools are allowed without prompting |

Prefix denies are not a hard boundary: `sh -c '…'` or an absolute path does
not match them. With sandboxed commands auto-approved, those forms run without
a prompt, but only inside the sandbox.

### Where each list goes

| List | Codex | Claude | Cursor | Copilot | OpenCode |
|---|---|---|---|---|---|
| `commands.allowed` | — (left to the sandbox) | `Bash(…)` allow | `Shell(…)` allow | `--allow-tool` prefixes | allow |
| `commands.exact` | — (prefix rules only) | `Bash(…)` allow | `Shell(…)` allow | `--allow-tool` without prefix wildcard | allow |
| `commands.sandboxAsk` | `prompt` rule | ask | — | Unlisted; normal approval | — |
| `commands.routine` | — (sandbox policy) | — except `terraform validate` ask | — | Unlisted; normal approval | — |
| `commands.sandboxAsk ++ commands.routine` | — | — | — | — | ask |
| `commands.denied` | `forbidden` rule | deny | deny | `--deny-tool` | deny |
| `paths.homeReadable` | `read` (`paths.readable`) | — (home readable) | — | `readonlyPaths` (`paths.readable`) | — |
| `paths.homeSecrets` | `deny` (`paths.denied`) | `Read(…)` deny, also a sandbox read deny | `Read(…)` deny | sandbox `deniedPaths` | — |
| `paths.secretFiles` | workspace deny | `Read(…)` deny | `Read(…)` deny | — | — |
| `.env` files | workspace deny | `Read`/`Edit` deny | `Read`/`Write` deny | `write(.env)` deny | `read` deny |
| `network.fetch` | — | — | `WebFetch(…)` allow | `allowedUrls` | — |
| `network.sandbox` | proxy `domains` | `allowedDomains` and `WebFetch(domain:…)` allow | `networkAllowlist` | `allowedHosts` | — |
| `paths.readonly` | `read` | — (reads allowed) | `additionalReadonlyPaths` | `readonlyPaths`, `--add-dir` | — |
| `paths.runtime` | `read` | — (reads allowed) | — (reads allowed) | `readonlyPaths` | — |
| `paths.tmp` | `:slash_tmp`, `:tmpdir` write | `allowWrite` | `additionalReadwritePaths` | `readwritePaths` | — |
| `paths.nixDaemonSocket` | `unix_sockets`, `read` | `allowUnixSockets` | — | `readwritePaths` | — |
| `caches` | `shell_environment_policy`, `write` | `env`, `allowWrite` | wrapped binary, `additionalReadwritePaths` | wrapper env, `readwritePaths` | — |
| `mcpServers` | — | `mcp__<server>__*` allow | `Mcp(…)` allow | `--allow-tool` | — |

Codex and Claude run project code (`just`, `npm run`, `npx`,
`npm test`, `cargo test`, installed formatters) inside their sandboxes
without prompts; access beyond the sandbox grants still needs approval. Claude
retains its `terraform validate` ask rule because `terraform *` is
deliberately excluded from its sandbox for macOS TLS compatibility.
Copilot leaves these runners unlisted so they require normal approval.

`nix build` and `nix fmt` keep approval in Codex and Claude because they build
through the Nix daemon, outside the agent sandbox. Wrappers such as `just` can
still reach the daemon without that prompt; prefix rules don't see inside
them. Copilot leaves `nix build` and `nix fmt` unlisted. Cursor and
OpenCode retain their existing behavior.

Claude's WebFetch allow rules also widen its Bash sandbox network, so Claude
gets `network.sandbox` instead of `network.fetch` there.

Copilot checks the paths of its own file tools separately from the sandbox:
anything outside the working directory prompts. `--add-dir` lifts that for
`paths.readonly` and also trusts any `.github/skills` and
`.github/agents` there. Its `write()` rules match trailing path components,
and it has no `read()` rule, so `paths.secretFiles` and `.env` reads are not
denied for Copilot.

### Rex control requires review

Rex can start commands through a separately running server or type into an
existing terminal. Those processes use the server's account and permissions;
they do not inherit the calling agent's sandbox. Treat approved Rex control
as access to that account. The GUI's Remote Control toggle gates app actions,
not necessarily server commands such as `run`, `split`, `send` and API calls.
See [Rex shell scripting](https://www.superlogical.com/rex/docs/automate/shell-scripting).

Codex and Claude prompt for all Rex invocations, including guide and help
commands. The shared list covers `rex`, profile links, the pinned CLI's store
path and the helper executable in standard system/user Rex app bundles.
Codex 0.166.0 also resolves other absolute paths ending in `/rex` through its
basename rule; Claude has additional `/rex` path wildcard ask rules. OpenCode
receives the shared ask rules and already asks for unlisted commands.
These rules apply after switching and restarting the agent CLI.

The stronger boundary is connection access: Codex's network proxy and Claude's
Unix-socket allowlist permit only the Nix daemon socket, with allow-all socket
access explicitly false. No Rex endpoint is added to the network allowlist.
Keep it that way: enabling a Rex socket or control host can delegate execution
outside the sandbox. Tailscale authentication does not sandbox commands.

Command rules do not inspect arbitrary scripts, renamed binaries or every
wrapper. A broader executable allow rule may also affect path matching, so
review saved approvals. Avoid persistent broad Rex approvals. `/Applications`
execution retains the calling process's sandbox; its directory location alone
does not grant server access. A blanket application-directory prompt is not
used here.

Copilot has no blanket shell grant: Rex control calls are unlisted and require
normal approval. Reset saved session grants with `/reset-allowed-tools` after
restarting with the new flags; an old broad shell approval can defeat this
default. Its `allowLocalNetwork = false` prevents automatic localhost access;
the filesystem policy grants no Rex control socket. Actual prompts and
connection blocking still need verification after applying.

Cursor has no equivalent per-command ask rule in this setup, and Pi has no
permission boundary. They are not covered by the Rex prompt policy.
Do not assume their Rex skill implies safe server access; use an isolated
account or VM when a hard account boundary is required.

### CLI-specific lists

| CLI | Setting | Contents |
|---|---|---|
| Claude | `sandbox.excludedCommands` | `gh *`, `terraform *`, `go get *`, `go mod download`, `go mod tidy`: run outside the sandbox through the normal permission flow |
| Claude | `sandbox.filesystem.denyWrite` | `**/.git/hooks`, `**/.git/config` |
| Claude | `sandbox.filesystem.allowRead` | The repo's `dotfiles/.npmrc`, which `~/.npmrc` links to |
| Claude | `sandbox.network.allowUnixSockets` | Nix daemon socket |
| Claude | `sandbox.enableWeakerNetworkIsolation` | `false`; see [Go CLIs and TLS](#go-clis-and-tls) |
| Claude | `sandbox.network.strictAllowlist` | `false`: unlisted hosts prompt |
| Codex | `filesystem` | Workspace `.git` writable, hooks and config read-only, `~/.codex/skills` |
| Copilot | `readonlyPaths` / `readwritePaths` | Copilot hooks; herdr socket and backlog vault |
| Copilot | `--allow-tool` | Shared safe prefixes/exact commands and catalog MCP servers; no blanket shell grant |
| Copilot | `sandbox.userPolicy.network.allowLocalNetwork` | `false`; localhost/private-network access is not implicitly granted |
| Copilot | `--deny-tool` | `write(.git/config)`, for its file tools only |
| Copilot | `clearPolicyOnExit` | `true` |

## Sandbox boundaries

| | Codex | Claude | Cursor | Copilot |
|---|---|---|---|---|
| Reads | Under `~`: workspace and `paths.homeReadable`; elsewhere only tool paths and Codex's runtime set | Allowed everywhere except denied reads | Allowed (system read boundary) | Working directory, PATH, temp, `paths.homeReadable`, dev-tool paths |
| Denied reads | `paths.homeSecrets`, `.env`, keys | `paths.homeSecrets`, `.env`, keys | Credential paths | `paths.homeSecrets` |
| Writes | Workspace, `$TMPDIR`, `/tmp`, agent caches, macOS runtime scratch (`/var/tmp`) | Working directory, `$TMPDIR`, `/tmp`, agent caches | Workspace, temp, `/tmp`, agent caches | Working directory, temp, `/tmp`, agent caches, dev-tool caches (`allowDevToolAccess`) |
| Read-only in the workspace | `.git/hooks`, `.git/config` | `.git/hooks`, `.git/config` | `.git/hooks`, `.git/config` (sandbox default, plus `Write(…)` deny) | `.git/config` for file tools only |
| Network | `network.sandbox`; other hosts ask for approval | `network.sandbox`; other hosts prompt | `network.sandbox` plus Cursor's default list | `network.sandbox`; other hosts offer a bypass prompt |
| Unsandboxed | Approved escalations | `gh`, `terraform`, Go module downloads, approved retries | Approved escapes | Approved bypasses |
| Unix sockets | Nix daemon only | Nix daemon only | — | Nix daemon, herdr |

Git runs hooks and config outside the sandbox, so both are read-only to
prevent an escape. Nix builds run unprivileged through the daemon.

Codex and Copilot deny reads under `~` except the workspace and
`paths.homeReadable`, and deny `paths.homeSecrets` inside those; the narrower
path wins. Reading elsewhere in `~` fails in the sandbox, so the agent has to
ask to run the command outside it.

Claude keeps the home directory readable and denies only `paths.homeSecrets`,
`.env` files and keys. A `~/` deny in its user settings would also block the
project, because user settings can't name it (`.` there means `~/.claude`);
only a per-project `allowRead: ["."]` or a launch wrapper could allow it
back. The network allowlist limits where readable data could go.

### Codex permission profiles and workspace modes

`codex.nix` selects the custom profile `workspace-only` with
`default_permissions`. The name is ours; it does not mean Codex grants access
only to the repository. The profile inherits `:workspace`, replaces its
whole-disk read grant with `:root = "deny"`, and adds runtime paths, shared
tool paths, selected home paths, agent caches, and credential exclusions.

The following names were checked against Codex CLI **0.166.0**. Built-in
permission profiles and the CLI's `--sandbox` choices are separate ways of
selecting permissions:

| Permission profile | CLI sandbox mode | Baseline behavior |
|---|---|---|
| `:read-only` | `read-only` | Whole-disk reads, no ordinary filesystem writes; network restricted by default |
| `:workspace` | `workspace-write` | Whole-disk reads, workspace and temporary-directory writes, protected workspace metadata; network restricted by default |
| `:danger-full-access` | `danger-full-access` | No Codex OS sandbox; approval policy is a separate setting |
| `workspace-only` (this repo) | Custom named profile | Restricted reads, workspace/temp/cache writes, proxy-controlled network, and explicit exclusions |

There is no `workspace-edit` sandbox mode in this version. `workspace-write`
allows both edit tools and shell commands to modify permitted files; it is
not an edit-tool-only mode. Selecting the plain built-in workspace profile
would lose this repository's custom read boundary and exclusions. Keep the
custom profile for normal work. A read-only profile is useful for inspection,
but the plain built-in still permits broad reads.

Keep `default_permissions` as the configuration interface here. Do not also
set the legacy `sandbox_mode` or `[sandbox_workspace_write]` settings; the
[configuration reference](https://developers.openai.com/codex/config-reference/)
documents them as incompatible with named permission profiles.

`extends` can name `:workspace`, `:read-only`, or another custom profile;
child keys override matching parent keys. `:danger-full-access` cannot be
used as an inheritance parent. Starting without `extends` is possible, but
requires spelling out runtime access, workspace grants, and metadata
protections. Keeping `extends = ":workspace"` preserves the built-in
protections for `.agents`, `.codex`, and `.aws`; this repo deliberately
overrides `.git` to allow commits while retaining read-only hooks and config.
See the versioned [profile resolver](https://github.com/openai/codex/blob/rust-v0.166.0/codex-rs/core/src/config/permissions.rs)
and [built-in profile definitions](https://github.com/openai/codex/blob/rust-v0.166.0/codex-rs/protocol/src/models.rs).

### Codex filesystem keys

These special keys belong inside a permission profile's `filesystem` table;
they are not profile names. `read` permits reads, `write` permits reads and
writes, and `deny` permits neither. More specific path rules can narrow or
expand broader grants. See the versioned [filesystem policy](https://github.com/openai/codex/blob/rust-v0.166.0/codex-rs/protocol/src/permissions.rs).

| Key | Meaning in this configuration |
|---|---|
| `:root` | Filesystem-wide baseline. `deny` replaces inherited whole-disk reads; explicit grants reopen selected paths |
| `:minimal` | Enables Codex's platform runtime bundle for restricted reads; its macOS scope is described below |
| `:workspace_roots` | Applies the nested rules to each workspace root. `"." = "write"` grants workspace access; narrower entries protect hooks, config, and secrets |
| `:tmpdir` | The runtime temporary directory (`$TMPDIR` on macOS); explicitly writable here |
| `:slash_tmp` | `/tmp`, physically `/private/tmp` on macOS; explicitly writable here |
| Absolute path | A grant or exclusion for a particular location, such as `/nix/store` or an agent cache |

The profile-level `workspace_roots` setting adds named roots (path-to-boolean
entries); `--add-dir` adds writable directories for a launch. These differ
from `filesystem.:workspace_roots`, which defines the access rules applied
to roots. Use a specific absolute path grant for a tool or cache that should
not be treated as another project. `--cd` selects the working directory;
`--worktree` creates a managed Git worktree. None is a replacement for the
read restrictions in this profile. See the [profile configuration types](https://github.com/openai/codex/blob/rust-v0.166.0/codex-rs/config/src/permissions_toml.rs)
and `codex --help`.

#### What `:minimal` includes on macOS

This is a versioned runtime bundle, not a short alias for the explicit
`paths.runtime` list in `permissions.nix`. In Codex 0.166.0 it supplies system
executables, libraries and frameworks, `/etc` configuration, selected system
data and preferences, device access, and selected macOS runtime services.
The bundle includes limited device writes and IPC permissions as well as
reads; `"read"` does not make the entire bundle read-only. See the complete
[macOS runtime policy](https://github.com/openai/codex/blob/rust-v0.166.0/codex-rs/sandboxing/src/seatbelt_read_only_platform_defaults.sbpl).

For shell processes, Codex additionally grants reads beneath **all of
`/Applications`**, and scratch reads/writes beneath `/private/tmp` and
`/private/var/tmp` (also reached through `/tmp` and `/var/tmp`). Scratch grants
are lowered with filesystem exclusions. Filesystem-helper profiles do not
receive these process-only additions. See the [Seatbelt builder](https://github.com/openai/codex/blob/rust-v0.166.0/codex-rs/sandboxing/src/seatbelt.rs#L992-L997)
and [scratch policy](https://github.com/openai/codex/blob/rust-v0.166.0/codex-rs/sandboxing/src/seatbelt_scratch.rs).

This explains why a bundled CLI such as Rex can run from `/Applications`
without a new approval. The child process remains sandboxed; execution does
not grant application-directory writes. A separately running server has its
own permissions, and connecting to it is subject to IPC/network policy.

Keep `:minimal` for normal command startup. Removing it requires maintaining
the OS runtime allowances yourself and can prevent shells from starting.
Recheck the versioned implementation after Codex updates: the bundle's scope
is not fully visible in the explicit path list shown to the model.

### Codex approvals and network settings

Filesystem access, network access, and approval routing are independent.
`approval_policy = "on-request"` allows requests for wider access;
`approvals_reviewer = "user"` sends those requests to the user. `never`
disables approval requests rather than granting more access. Prompt and
forbidden command rules add review requirements to the sandbox policy.

`network.enabled = true` enables networking subject to the proxy.
`features.network_proxy = true` makes the domain rules enforceable; `domains`
allows package hosts and other hosts require approval. `mode = "full"`
avoids the extra request-method and HTTPS restrictions of `limited` mode;
it does not bypass the domain rules. `allow_local_binding = false` and
`allow_upstream_proxy = false` withhold those capabilities. The
`unix_sockets` entry permits the Nix daemon connection separately from TCP
hosts, and its filesystem read grant permits socket probes. These proxy
rules govern sandboxed commands, not hosted web search, apps, or MCP servers.
See the
[configuration reference](https://developers.openai.com/codex/config-reference/).

### Unlisted hosts

Hosts outside `network.sandbox` should ask, not fail:

- Codex: the proxy runs in `full` mode, so other hosts go through on-request
  approval.
- Claude: in the default `acceptEdits` mode, a sandboxed command waits for a
  prompt. Auto mode refuses the host unless the command declares it, and
  `dontAsk` refuses it.
- Copilot: `allowedHosts` blocks other hosts in the sandbox; Copilot then
  offers to re-run the command outside the sandbox (changelog: "Sandboxed
  shell commands offer a network bypass prompt whenever the proxy blocks a
  destination").
  Local-network access is explicitly off, including implicit localhost grants.
- Cursor: unlisted hosts are blocked inside the sandbox; whether Cursor
  then offers to run the command outside it is not verified.

## Agent caches

Unsandboxed builds trust the user's normal caches, so writes to them would
escape the sandbox. Sandboxed package managers get their own writable caches
under `~/.cache/<tool>-agent` instead:

| Tool | Variable | Path |
|---|---|---|
| Nix | `NIX_CACHE_HOME` | `~/.cache/nix-agent` |
| Cargo | `CARGO_HOME` | `~/.cache/cargo-agent` |
| Go | `GOCACHE`, `GOMODCACHE` | `~/.cache/go-agent/{build,mod}` |
| mise | `MISE_CACHE_DIR` | `~/.cache/mise-agent` |
| npm | `npm_config_cache` | `~/.cache/npm-agent` |
| Homebrew | `HOMEBREW_CACHE` | `~/.cache/homebrew-agent` |

Home Manager creates these directories on activation. Homebrew checks that
its cache or parent is writable before use; without the dedicated cache,
sandboxed hooks can fall back to `/opt/homebrew/tmp/cache` and fail because
the Homebrew installation is read-only.

Codex and Claude set the variables in their own config. Copilot's zsh wrapper
sets them when starting a session, and Cursor's binary is wrapped to set them;
neither has an env setting. The variables also apply to approved commands
outside the sandbox. The first build in each cache downloads dependencies
again.

The same env sets `NVIM_LOG_FILE=/dev/null`. Sandboxed Neovim can't create
its RPC socket or open its log under `~/.local/state`, so without it every
headless `nvim` run writes a `server_start` warning to `./nvim.log` in the
working directory.

mise installs (`~/.local/share/mise`) stay read-only: they are programs the
user runs outside the sandbox. Run `mise install` outside the sandbox. mise's
state directory (`~/.local/state/mise`) is not covered.

Copilot's `allowDevToolAccess` grants a moved cache instead of its default
location, but only to commands of the same ecosystem, so the agent caches are
also in `readwritePaths`. Its default "user profile" grant may still reach the
normal caches; that is not verified.

## Claude Code certificate store

After the eMudhra CA compromise, the nixpkgs wrapper sets
`CLAUDE_CODE_CERT_STORE=system` ([nixpkgs#576509](https://github.com/NixOS/nixpkgs/pull/576509))
so Claude Code stops trusting the Mozilla roots compiled into its binary. On
macOS that store reads only the login and System keychains, not Apple's
built-in roots, so TLS fails with `UNABLE_TO_GET_ISSUER_CERT_LOCALLY`
([llm-agents.nix#11153](https://github.com/numtide/llm-agents.nix/issues/11153)).

`claude-code.nix` keeps the `system` store and sets
`env.NODE_EXTRA_CA_CERTS = "/etc/ssl/certs/ca-certificates.crt"`. That
bundle comes from nixpkgs `cacert` with nix-darwin's `security.pki`
distrust list, so it follows root removals. Avoid
`CLAUDE_CODE_CERT_STORE = "bundled"`: it trusts whatever roots that Claude
Code release ships.

Apple's `/etc/ssl/cert.pem` is a separate store used by `/usr/bin/curl`, git
and python3, and it still includes the affected roots. Apple's
[support article](https://support.apple.com/en-us/149555) describes optional
manual removal. This repository does not manage that file.

If a network needs a private CA, set `NODE_EXTRA_CA_CERTS` in private host
configuration to a bundle that contains both the private CA and
`/etc/ssl/certs/ca-certificates.crt`, because the private value replaces this
one. See Claude's [network configuration guide](https://code.claude.com/docs/en/network-config).
Apply the configuration and restart Claude Code for the setting to take effect.

## Go CLIs and TLS

Go CLIs such as `gh` and `terraform` can't verify TLS under Claude's Seatbelt
sandbox: macOS certificate checks need `trustd`, which the sandbox blocks
(`x509: OSStatus -26276`).

- Claude runs `gh` and `terraform` outside the sandbox (`excludedCommands`).
  Allow rules (`gh pr view`, `terraform fmt`) run without prompting, deny
  rules (`gh auth`, `gh api`) still apply, `terraform validate` keeps its ask
  rule, and everything else asks. The exclusion matches the command text, so
  `just` recipes, scripts, or absolute paths that call them stay sandboxed.
- `enableWeakerNetworkIsolation = true` would open `trustd` to the sandbox
  instead, at the cost of a possible exfiltration channel. It is explicitly
  off in `claude-code.nix`.
- Go module downloads (`go get`, `go mod download`, `go mod tidy`) hit the
  same failure, so Claude excludes them too. They aren't allowlisted, so they
  prompt, and the agent cache env still puts modules in `~/.cache/go-agent`.
  `go build` and `go test` stay sandboxed because they run project code;
  they work with modules already in the cache, but a toolchain download
  (`GOTOOLCHAIN=auto`) or a missing module still needs an unsandboxed retry.
- Codex and Cursor have no exclusion list; a failing command goes through
  their escalation prompt. Copilot authenticates sandboxed `gh` through its
  masking proxy. Neither path is verified for the TLS failure.

## Edits through scripts

Agents sometimes edit files with Python or `sed` instead of the edit tool.
Inside the sandbox these are limited to the same write paths, and in Claude
they no longer prompt. They bypass edit-tool features, though: `Edit(…)`
permission rules, `/rewind` checkpoints, `Edit|Write` hooks, diff review, and
the stale-file and unique-match checks. Auto-accepting edit-tool edits keeps
agents from preferring scripts just to avoid prompts.

## Changing the setup

- Shared policy: `nix/modules/home/programs/ai/permissions.nix`
- Native permission adapters: each CLI's module (`claude-code.nix`,
  `codex.nix`, `cursor-cli.nix`, `github-copilot-cli.nix`, `opencode.nix`)
- Claude sandbox, exclusions, and mode: `claude-code.nix`
- Codex profile, proxy, command rules, and git worktree grants: `codex.nix`
- Copilot sandbox, cache env, and tool flags: `github-copilot-cli.nix`
- Cursor sandbox, network allowlist, and cache wrapper: `cursor-cli.nix`

Copilot reads tool rules only from CLI flags, so a zsh wrapper adds them when
a session starts. Claude, Copilot, Cursor, and Codex rewrite their own config
files, so Nix merges its settings into them on activation instead of
symlinking (`nix/modules/home/merge-config.py`). The last applied settings are kept under
`~/.local/state/nix-config/merged/`, so settings removed from Nix are removed
from the files too. OpenCode loads its Nix settings as a separate Home Manager
layer instead.

Agent merges validate the complete candidate against a bundled schema when one
is available before replacing the config or merge state. Builds check generated
settings, and activation checks the final global files. Run
`just validate-agent-config` for a read-only check; its output distinguishes
schema coverage, parsing-only checks and missing files. See
[configuration validation](agent-project-tools.md#configuration-validation)
for schema sources, cleanup checks and coverage limits.

No MCP server is configured globally. Projects list theirs in each agent's
project files through `ct agents` (see
[agent-project-tools.md](agent-project-tools.md)); the catalog's servers
(`mcp.nix`) have their tools allowed without prompting, in Claude Code as
`mcp__<server>__<tool>`. The CLIs' own servers are off: Claude's claude.ai
connectors (`disableClaudeAiConnectors`), Codex's ChatGPT apps
(`features.apps`) and bundled plugins (`plugins.<name>.enabled`), and
Copilot's GitHub servers (`--disable-builtin-mcps`). Global tools enabled by
hand are reset on the next switch by `cleanup-agent-config`; enable them in
project files instead. See the [cleanup guide](agent-project-tools.md#global-cleanup).
The Claude desktop app delivers its connectors itself; disconnect them at
claude.ai.

Built-in skills are off as well. Claude syncs no plugins or skills from
claude.ai (`syncClaudeAiPlugins`, `syncClaudeAiSkills`), and its bundled
skills other than `artifact-*` are `user-invocable-only` through
`skillOverrides`: hidden from the model, still typable with `/`. Bundled skills
added in a newer Claude Code release are on until they're listed there. Codex
turns off its system skills (`skills.bundled.enabled`) and explicitly disables
the cached `review-agent`, `skill-creator`, `skill-installer`, `openai-docs`,
and `imagegen` paths through `skills.config`. Path selectors leave project
skills with the same names available. The supported per-skill format is in
the [Codex skills guide](https://developers.openai.com/codex/skills/).
Copilot lists its built-in skills in `disabledSkills`. Cursor syncs its built-in skills into
`~/.cursor/skills-cursor` and has no setting that turns them off.

## Working in the sandboxes

What an agent (or a person reading its transcript) should expect inside the
Codex, Claude, Cursor, and Copilot sandboxes. A denial here is usually the
boundary working, not a bug to work around.

### What works

- **Writes:** the workspace, `$TMPDIR`, `/tmp`, and `~/.cache/<tool>-agent`.
  Use `/tmp` or `$TMPDIR` for scratch files, not the home directory. Claude
  prompts for commands with variables, so it uses literal `/tmp` paths.
- **Package caches:** Nix, Cargo, Go, mise, npm, and Homebrew already point at the
  agent caches through env vars. Builds and tests that only need cached
  dependencies run without prompts. The first build in a session's cache
  downloads dependencies again.
- **Network:** hosts in `network.sandbox` (Nix registry, PyPI, crates
  index, Go proxy and checksum DB, mise version index, SchemaStore).
- **Git:** status, diff, add, and commit. Hooks and `.git/config` are
  read-only.
- **Nix:** evaluation, and builds through the daemon after approval
  (`nix build`, `nix fmt`).

For nix-config validation, agents use the tracked `nix/fixtures/host` input
with `--override-input host "path:$PWD/nix/fixtures/host"` from the repository
root (see `AGENTS.md`). It contains synthetic identity and paths, disables
nested virtualization, and imports no private modules. Routine validation
does not read or request access to `~/.config/nix-config-host`. The user
validates the real host configuration manually before applying it. Build
and network approval rules still apply; never activate the fixture system.

### What needs approval

| Action | What happens |
|---|---|
| Other hosts (npm registry, GitHub, docs sites) | Codex and Claude prompt; Copilot offers a sandbox bypass; in Claude's auto mode the command must declare the host |
| `gh`, `terraform`, `go get`, `go mod download`, `go mod tidy` | Claude runs them outside the sandbox after a prompt unless an allow rule matches; other CLIs need an escalation |
| `go build` or `go test` that downloads a toolchain or missing module | Escalation, because Go TLS fails in the sandbox |
| Codex, Claude: `nix build`, `nix fmt` | Prompt: they build through the daemon, outside the agent sandbox |
| `just`, `npm run`, `npx`, `npm test`, `cargo test` | Codex and Claude run sandboxed without prompts; Copilot requires normal approval; OpenCode retains ask rules |
| `terraform validate` | Codex runs it sandboxed; Copilot requires normal approval; Claude prompts because Terraform runs outside its sandbox; OpenCode retains its ask rule |
| `mise install`, `mise trust` | Run outside the sandbox; `mise trust` is denied for agents, so ask the user |
| Claude commands with `$VAR`, `$(...)` or backticks | Prompt ("A variable in this command can't be checked"), since the expansion could match an ask or excluded command; the global `CLAUDE.md` tells Claude to use literal paths instead |

### What fails on purpose

- Codex and Copilot: reading the home directory outside the workspace and
  `paths.homeReadable` (other projects, `~/Documents`, `~/Library`,
  shell history).
- Reading credentials: `~/.ssh`, `~/.aws`, `~/.gnupg`,
  `~/.config/gh`, `~/.config/op`, `~/.netrc`, `~/.npmrc`, agent auth files,
  `.env` files, `*.pem`, `*.key`. Ask the user if a task really needs one.
- Writing the normal caches and tool installs: `~/Library/Caches`,
  `~/.cache/<tool>`, `~/golang`, `~/.cargo`, `~/.npm`, `~/.local/share/mise`,
  `~/.local/state/mise`.
- `op`, `security`, `sudo`, `gh auth`, `gh api`, `darwin-rebuild`,
  `just switch`, `git push --force`.
- Interactive programs that need `/dev/tty` (lazygit, editors, pagers), and
  `open` or `osascript` in Claude.

### Error signatures

| Error | Cause | Do instead |
|---|---|---|
| `Operation not permitted` on a write | Path outside the writable set | Write to the workspace or `$TMPDIR`; don't retarget caches |
| `x509: OSStatus -26276` | Go TLS can't reach `trustd` in Seatbelt | Run the command outside the sandbox, or `go mod download` first |
| `Forbidden`, `CONNECT tunnel failed, response 403` | Host not on the sandbox list | Request approval for that host |
| `failed to copy trust settings of system certificate` | Same `trustd` block, printed by Node tools | Harmless when the command otherwise succeeds |
| `device not configured` on `/dev/tty` | No terminal in the sandbox | Use a non-interactive flag (`--no-pager`, `-y`, `GIT_EDITOR=true`) |

### Rules of thumb

- Retry a failed command once, with escalation, only when the error matches
  the sandbox; don't loop or try variants.
- Don't work around a denial: no `sh -c` or absolute paths to dodge a
  command rule, no `GOINSECURE`, `GONOSUMDB`, `GOPROXY=direct`, or
  `NODE_TLS_REJECT_UNAUTHORIZED=0`, and no copying credentials into the
  workspace.
- Don't override the agent cache variables (`GOCACHE`, `GOMODCACHE`,
  `CARGO_HOME`, `MISE_CACHE_DIR`, `npm_config_cache`, `NIX_CACHE_HOME`), or
  `GOROOT`.
- When something genuinely needs the user's access (installs, credentials,
  applying the system config), stop and say what to run.

### For AGENTS.md

A short block for a project's `AGENTS.md`, pointing back here for details:

```markdown
## Agent sandbox

Commands run in an OS sandbox (see nix-config `docs/agent-permissions.md`).

- Writable: the workspace, `$TMPDIR`, `/tmp`, and `~/.cache/<tool>-agent`;
  package caches already point there. Use `/tmp` for scratch files.
- Network: package download hosts only; other hosts need approval.
- `Operation not permitted`, `403`/`Forbidden`, or `x509: OSStatus -26276`
  mean the sandbox blocked it: retry once with escalation or ask, don't try
  variants or work around it.
- Credentials (`~/.ssh`, `~/.aws`, `.env`, keys) and tool installs
  (`mise install`) are off-limits; ask the user.
- Avoid interactive commands; pass non-interactive flags.
```
