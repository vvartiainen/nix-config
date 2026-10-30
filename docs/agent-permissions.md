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
| Copilot | Run without approval (`--allow-tool shell`) | Prompted | Sandbox bypasses, unlisted hosts, file edits |
| OpenCode | No sandbox; `*` is ask | CLI default | Everything not allowlisted |
| Pi | No permission config | — | — |

Copilot has no "approve if sandboxed" setting, so it gets a blanket
`--allow-tool shell` grant; deny rules still take precedence, and running a
command outside the sandbox is a separate bypass prompt. Its sandbox network
is limited to `network.sandbox`, like Codex and Claude. The grant does not
depend on the sandbox: after `/sandbox disable`, shell commands run
unsandboxed without prompts. OpenCode has no OS sandbox, so its
rules are the only boundary. Pi has neither; anything it runs uses the user's
normal access.

## Shared lists

These policy values live in `permissions.nix`. Paths and caches are resolved
from the importing Home Manager configuration.

| List | Purpose |
|---|---|
| `commands.allowed` | Read-only prefixes (`git status`, `nix eval`, `gh pr view`, `terraform fmt`, …) allowed everywhere, including outside a sandbox |
| `commands.exact` | Allowed only as written (`git branch --show-current`); their prefixes would allow destructive forms |
| `commands.sandboxAsk` | Daemon-backed Nix commands (`nix fmt`, `nix build`) that build outside the agent sandbox; prompt in Codex and Claude |
| `commands.routine` | Project-code runners and wrappers (`just`, `npm run`, `npx`, `npm test`, `cargo test`, `terraform validate`); sandbox approval everywhere except Claude Terraform, ask in OpenCode |
| `commands.denied` | Never auto-approved (`op`, `security`, `gh auth`, `gh api`, `sudo`, `darwin-rebuild`, `just switch`, `git push --force`, `mise trust`) |
| `paths.homeReadable` | Home paths sandboxed commands may read (`.config`, `.local/share`, `.local/state`, `.cache`, shell startup files, Nix profiles, toolchains); the rest of `~` is denied |
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
| `commands.allowed` | — (left to the sandbox) | `Bash(…)` allow | `Shell(…)` allow | — (`--allow-tool shell`) | allow |
| `commands.exact` | — (prefix rules only) | `Bash(…)` allow | `Shell(…)` allow | — (`--allow-tool shell`) | allow |
| `commands.sandboxAsk` | `prompt` rule | ask | — | — (`--allow-tool shell`) | — |
| `commands.routine` | — (sandbox policy) | — except `terraform validate` ask | — | — (`--allow-tool shell`) | — |
| `commands.sandboxAsk ++ commands.routine` | — | — | — | — | ask |
| `commands.denied` | `forbidden` rule | deny | deny | `--deny-tool` | deny |
| `paths.homeReadable` | `read` (`paths.readable`) | — (home readable) | — | `readonlyPaths` (`paths.readable`) | — |
| `paths.homeSecrets` | `deny` (`paths.denied`) | `Read(…)` deny, also a sandbox read deny | `Read(…)` deny | sandbox `deniedPaths` | — |
| `paths.secretFiles` | workspace deny | `Read(…)` deny | `Read(…)` deny | — | — |
| `.env` files | workspace deny | `Read`/`Edit` deny | `Read` deny | `write(.env)` deny | `read` deny |
| `network.fetch` | — | — | `WebFetch(…)` allow | `allowedUrls` | — |
| `network.sandbox` | proxy `domains` | `allowedDomains` and `WebFetch(domain:…)` allow | `networkAllowlist` | `allowedHosts` | — |
| `paths.readonly` | `read` | — (reads allowed) | `additionalReadonlyPaths` | `readonlyPaths`, `--add-dir` | — |
| `paths.runtime` | `read` | — (reads allowed) | — (reads allowed) | `readonlyPaths` | — |
| `paths.tmp` | `:slash_tmp`, `:tmpdir` write | `allowWrite` | — | `readwritePaths` | — |
| `paths.nixDaemonSocket` | `unix_sockets`, `read` | `allowUnixSockets` | — | `readwritePaths` | — |
| `caches` | `shell_environment_policy`, `write` | `env`, `allowWrite` | wrapped binary, `additionalReadwritePaths` | wrapper env, `readwritePaths` | — |
| `mcpServers` | — | `mcp__<server>__*` allow | `Mcp(…)` allow | `--allow-tool` | — |

Codex, Claude, and Copilot run project code (`just`, `npm run`, `npx`,
`npm test`, `cargo test`, installed formatters) inside their sandboxes
without prompts; access beyond the sandbox grants still needs approval. Claude
retains its `terraform validate` ask rule because `terraform *` is
deliberately excluded from its sandbox for macOS TLS compatibility.

`nix build` and `nix fmt` keep approval in Codex and Claude because they build
through the Nix daemon, outside the agent sandbox. Wrappers such as `just` can
still reach the daemon without that prompt; prefix rules don't see inside
them. Copilot's blanket shell grant also covers `nix build`. Cursor and
OpenCode retain their existing behavior.

Claude's WebFetch allow rules also widen its Bash sandbox network, so Claude
gets `network.sandbox` instead of `network.fetch` there.

Copilot checks the paths of its own file tools separately from the sandbox:
anything outside the working directory prompts. `--add-dir` lifts that for
`paths.readonly` and also trusts any `.github/skills` and
`.github/agents` there. Its `write()` rules match trailing path components,
and it has no `read()` rule, so `paths.secretFiles` and `.env` reads are not
denied for Copilot.

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
| Copilot | `--allow-tool shell` | All shell commands; deny rules and bypass prompts still apply |
| Copilot | `--deny-tool` | `write(.git/config)`, for its file tools only |
| Copilot | `clearPolicyOnExit` | `true` |

## Sandbox boundaries

| | Codex | Claude | Cursor | Copilot |
|---|---|---|---|---|
| Reads | Under `~`: workspace and `paths.homeReadable`; elsewhere only tool paths and Codex's runtime set | Allowed everywhere except denied reads | Allowed (system read boundary) | Working directory, PATH, temp, `paths.homeReadable`, dev-tool paths |
| Denied reads | `paths.homeSecrets`, `.env`, keys | `paths.homeSecrets`, `.env`, keys | Credential paths | `paths.homeSecrets` |
| Writes | Workspace, `$TMPDIR`, `/tmp`, agent caches | Working directory, `$TMPDIR`, `/tmp`, agent caches | Workspace, agent caches | Working directory, temp, `/tmp`, agent caches, dev-tool caches (`allowDevToolAccess`) |
| Read-only in the workspace | `.git/hooks`, `.git/config` | `.git/hooks`, `.git/config` | — | `.git/config` for file tools only |
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
- **Package caches:** Nix, Cargo, Go, mise, and npm already point at the
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
| `just`, `npm run`, `npx`, `npm test`, `cargo test` | Sandboxed in Codex, Claude, and Copilot without prompts; OpenCode retains ask rules |
| `terraform validate` | Codex and Copilot run it sandboxed; Claude still prompts because Terraform runs outside its sandbox; OpenCode retains its ask rule |
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
