# Agent CLI permissions

Command rules, fetch domains, sandbox paths, and agent caches are defined once
in `nix/modules/home/programs/ai/permissions.nix` and rendered into each CLI's
native format. Each CLI module adds its own sandbox and approval settings.

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
| Copilot | Prompted unless allowlisted | Prompted | Everything not allowlisted |
| OpenCode | No sandbox; `*` is ask | CLI default | Everything not allowlisted |
| Pi | No permission config | — | — |

Copilot stays on manual approval. It has no "approve if sandboxed" setting,
only a blanket `--allow-tool shell`, and its default sandbox grants the user
profile and open outbound network, with a per-command bypass. OpenCode has no
OS sandbox, so its rules are the only boundary. Pi has neither; anything it
runs uses the user's normal access.

## Shared lists

All in `permissions.nix`.

| List | Purpose |
|---|---|
| `allowedCommands` | Read-only prefixes (`git status`, `nix eval`, `gh pr view`, `terraform fmt`, …) allowed everywhere, including outside a sandbox |
| `exactCommands` | Allowed only as written (`git branch --show-current`); their prefixes would allow destructive forms |
| `askCommands` | Run project-controlled code or build via the Nix daemon (`just`, `npm run`, `npx`, `cargo test`, `terraform validate`, `nix fmt`, `nix build`); always prompt, even when sandboxed |
| `deniedCommands` | Never auto-approved (`op`, `security`, `gh auth`, `gh api`, `sudo`, `darwin-rebuild`, `just switch`, `git push --force`, `mise trust`) |
| `homeSecretPaths` | Credential paths under `~` denied for reads (`.ssh`, `.config/op`, `.config/gh`, `.aws`, `.gnupg`, `.netrc`, `.npmrc`) |
| `secretFilePatterns` | Key files denied everywhere (`**/*.pem`, `**/*.key`); `.env` files are denied per CLI |
| `sandboxDeniedPaths` | `homeSecretPaths` as plain absolute paths, for sandboxes that don't take globs |
| `fetchDomains` | Docs and registry sites the web-fetch tools may read |
| `sandboxNetworkDomains` | Download-only hosts sandboxed commands may reach (Nix registry, PyPI, crates index, Go module proxy and checksum DB, mise version index, SchemaStore). Upload-capable registries (`registry.npmjs.org`, `crates.io`, `api.github.com`) are excluded |
| `sandboxReadonlyPaths` | Tool paths outside the sandboxes' built-in grants (`/nix/store`, Homebrew, mise data and config, aube store, git config) |
| `agentCaches` | Separate writable package manager caches (`writePaths`) and the env vars pointing tools at them (`env`) |
| `mcpServers` | Catalog MCP servers (`mcp.nix`) whose tools are allowed without prompting |

Prefix denies are not a hard boundary: `sh -c '…'` or an absolute path does
not match them. With sandboxed commands auto-approved, those forms run without
a prompt, but only inside the sandbox.

### Where each list goes

| List | Codex | Claude | Cursor | Copilot | OpenCode |
|---|---|---|---|---|---|
| `allowedCommands` | — (left to the sandbox) | `Bash(…)` allow | `Shell(…)` allow | `--allow-tool` | allow |
| `exactCommands` | — (prefix rules only) | `Bash(…)` allow | `Shell(…)` allow | `--allow-tool` | allow |
| `askCommands` | `prompt` rule | ask | — | — (all prompt) | ask |
| `deniedCommands` | `forbidden` rule | deny | deny | `--deny-tool` | deny |
| `homeSecretPaths` | — (reads outside the workspace denied) | `Read(…)` deny, also a sandbox read deny | `Read(…)` deny | sandbox `deniedPaths` | — |
| `secretFilePatterns` | workspace deny | `Read(…)` deny | `Read(…)` deny | — | — |
| `.env` files | workspace deny | `Read`/`Edit` deny | `Read` deny | — | `read` deny |
| `fetchDomains` | — | — | `WebFetch(…)` allow | `allowedUrls` | — |
| `sandboxNetworkDomains` | proxy `domains` | `allowedDomains` and `WebFetch(domain:…)` allow | `networkAllowlist` | — (open network) | — |
| `sandboxReadonlyPaths` | `read` | — (reads allowed) | `additionalReadonlyPaths` | `readonlyPaths` | — |
| `agentCaches` | `shell_environment_policy`, `write` | `env`, `allowWrite` | wrapped binary, `additionalReadwritePaths` | wrapper env, `readwritePaths` | — |
| `mcpServers` | — | `mcp__<server>__*` allow | `Mcp(…)` allow | `--allow-tool` | — |

Claude's WebFetch allow rules also widen its Bash sandbox network, so Claude
gets `sandboxNetworkDomains` instead of `fetchDomains` there.

### CLI-specific lists

| CLI | Setting | Contents |
|---|---|---|
| Claude | `sandbox.excludedCommands` | `gh *`, `terraform *`, `go get *`, `go mod download`, `go mod tidy`: run outside the sandbox through the normal permission flow |
| Claude | `sandbox.filesystem.denyWrite` | `**/.git/hooks`, `**/.git/config` |
| Claude | `sandbox.filesystem.allowRead` | The repo's `dotfiles/.npmrc`, which `~/.npmrc` links to |
| Claude | `sandbox.network.allowUnixSockets` | Nix daemon socket |
| Claude | `sandbox.enableWeakerNetworkIsolation` | `false`; see [Go CLIs and TLS](#go-clis-and-tls) |
| Claude | `sandbox.network.strictAllowlist` | `false`: unlisted hosts prompt |
| Codex | `filesystem` | Workspace `.git` writable, hooks and config read-only, `~/.codex/skills`, git and Nix profile paths, daemon socket |
| Codex | `network.unix_sockets` | Nix daemon socket |
| Copilot | `readonlyPaths` / `readwritePaths` | Copilot hooks; herdr socket and backlog vault |

## Sandbox boundaries

| | Codex | Claude | Cursor | Copilot |
|---|---|---|---|---|
| Reads | Denied outside the workspace, except tool paths and Codex's runtime set | Allowed everywhere except credential paths and `.env` files | Allowed (system read boundary) | Working directory, PATH, temp, user profile, dev-tool paths; credential paths denied |
| Writes | Workspace, agent caches | Working directory, `$TMPDIR`, agent caches | Workspace, agent caches | Working directory, temp, agent caches, dev-tool caches (`allowDevToolAccess`) |
| Read-only in the workspace | `.git/hooks`, `.git/config` | `.git/hooks`, `.git/config` | — | — |
| Network | `sandboxNetworkDomains`; other hosts ask for approval | `sandboxNetworkDomains`; other hosts prompt | `sandboxNetworkDomains` plus Cursor's default list | Open |
| Unsandboxed | Approved escalations | `gh`, `terraform`, Go module downloads, approved retries | Approved escapes | Approved bypasses |
| Unix sockets | Nix daemon only | Nix daemon only | — | — |

Git runs hooks and config outside the sandbox, so both are read-only to
prevent an escape. Nix builds run unprivileged through the daemon.

Claude's sandbox can read most of the disk; the network allowlist limits where
that data could go. Matching Codex would mean denying reads under `~` and
allowing back what tools need.

### Unlisted hosts

Hosts outside `sandboxNetworkDomains` should ask, not fail:

- Codex: the proxy runs in `full` mode, so other hosts go through on-request
  approval.
- Claude: in the default `acceptEdits` mode, a sandboxed command waits for a
  prompt. Auto mode refuses the host unless the command declares it, and
  `dontAsk` refuses it.
- Copilot: no `allowedHosts`, because a non-empty list blocks other hosts
  without a prompt. Every unlisted Copilot command is prompted anyway.
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

Codex and Claude set the variables in their own config. Copilot's zsh wrapper
sets them when starting a session, and Cursor's binary is wrapped to set them;
neither has an env setting. The variables also apply to approved commands
outside the sandbox. The first build in each cache downloads dependencies
again.

mise installs (`~/.local/share/mise`) stay read-only: they are programs the
user runs outside the sandbox. Run `mise install` outside the sandbox. mise's
state directory (`~/.local/state/mise`) is not covered.

Copilot's `allowDevToolAccess` grants a moved cache instead of its default
location, but only to commands of the same ecosystem, so the agent caches are
also in `readwritePaths`. Its default "user profile" grant may still reach the
normal caches; that is not verified.

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

- Shared lists: `nix/modules/home/programs/ai/permissions.nix`
- Claude sandbox, exclusions, and mode: `claude-code.nix`
- Codex profile, proxy, and git worktree grants: `permissions.nix`
  (`codexPermissions`) and `codex.nix`
- Copilot sandbox, cache env, and tool flags: `github-copilot-cli.nix`
- Cursor sandbox, network allowlist, and cache wrapper: `cursor-cli.nix`

Copilot reads tool rules only from CLI flags, so a zsh wrapper adds them when
a session starts. Claude, Copilot, Cursor, and Codex rewrite their own config
files, so Nix merges its settings into them on activation instead of
symlinking (`nix/modules/home/merge-config.py`). The last applied settings are kept under
`~/.local/state/nix-config/merged/`, so settings removed from Nix are removed
from the files too. OpenCode loads its Nix settings as a separate Home Manager
layer instead.

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

- **Writes:** the workspace, `$TMPDIR`, and `~/.cache/<tool>-agent`. Use
  `$TMPDIR` for scratch files, not `/tmp` or the home directory.
- **Package caches:** Nix, Cargo, Go, mise, and npm already point at the
  agent caches through env vars. Builds and tests that only need cached
  dependencies run without prompts. The first build in a session's cache
  downloads dependencies again.
- **Network:** hosts in `sandboxNetworkDomains` (Nix registry, PyPI, crates
  index, Go proxy and checksum DB, mise version index, SchemaStore).
- **Git:** status, diff, add, and commit. Hooks and `.git/config` are
  read-only.
- **Nix:** evaluation, and builds through the daemon after approval
  (`nix build`, `just`).

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
| Other hosts (npm registry, GitHub, docs sites) | Codex and Claude prompt; in Claude's auto mode the command must declare the host |
| `gh`, `terraform`, `go get`, `go mod download`, `go mod tidy` | Claude runs them outside the sandbox after a prompt unless an allow rule matches; other CLIs need an escalation |
| `go build` or `go test` that downloads a toolchain or missing module | Escalation, because Go TLS fails in the sandbox |
| `just`, `nix build`, `nix fmt`, `npm run`, `npx`, `cargo test`, `terraform validate` | Always prompt: they run project code or build outside the sandbox |
| `mise install`, `mise trust` | Run outside the sandbox; `mise trust` is denied for agents, so ask the user |
| Claude commands with `$VAR`, `$(...)` or backticks | Prompt ("A variable in this command can't be checked"), since the expansion could match an ask or excluded command; the global `CLAUDE.md` tells Claude to use literal paths instead |

### What fails on purpose

- Reading credentials: `~/.ssh`, `~/.aws`, `~/.gnupg`, `~/.config/gh`,
  `~/.config/op`, `~/.netrc`, `~/.npmrc`, `.env` files, `*.pem`, `*.key`.
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

- Writable: the workspace, `$TMPDIR`, and `~/.cache/<tool>-agent`; package
  caches already point there. Use `$TMPDIR` for scratch files.
- Network: package download hosts only; other hosts need approval.
- `Operation not permitted`, `403`/`Forbidden`, or `x509: OSStatus -26276`
  mean the sandbox blocked it: retry once with escalation or ask, don't try
  variants or work around it.
- Credentials (`~/.ssh`, `~/.aws`, `.env`, keys) and tool installs
  (`mise install`) are off-limits; ask the user.
- Avoid interactive commands; pass non-interactive flags.
```
