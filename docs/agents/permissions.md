# Agent permissions and sandboxes

The guidelines behind this policy are in
[design/agent-permissions](../design/agent-permissions.md).

Active session policy is authoritative. Apply configuration changes manually
and start fresh sessions. In T3 Code, use **Auto-accept edits** for Codex and
Claude when escapes should come to you; see [T3 Code permission modes](#t3-code-permission-modes).

## Client behavior

| CLI | Routine work | Approval boundary |
| --- | --- | --- |
| Codex | Workspace commands run sandboxed; ordinary internet access is allowed | Additional access and reviewed commands ask; all Rex/Kitty/Incus calls ask |
| Claude Code | Workspace edits and commands run sandboxed | Additional access and reviewed commands ask; Rex runs unsandboxed with approval; scoped `gh` and `fj` inspection is allowed outside the sandbox |
| Cursor | Workspace commands run sandboxed in Allowlist mode | Risky commands, uncertain shell syntax and unsandboxed retries ask |
| Copilot | Inspection, scoped development runners and file edits are approved | Unlisted commands and sandbox bypasses ask; `just lint` is scoped, other `just` recipes ask |
| OpenCode | Inspection commands and workspace file tools are allowed | No OS sandbox; project runners, cleanup and unknown commands ask |
| Pi | Whole process runs in Safehouse; routine file, bash and named web tools are allowed | Risky commands and unknown/MCP tools ask; approval cannot escape Safehouse |

Command rules supplement the sandbox; OpenCode's are best effort without OS
isolation. In Copilot, use `/reset-allowed-tools` to clear old broad grants
before testing changed rules. Claude's Code Mode retains the normal permission,
hook and sandbox checks.

## Working in the sandboxes

Write in the workspace, `$TMPDIR`, `/tmp` or `~/.cache/<tool>-agent`. Preserve
the configured cache variables. Normal caches and tool installations remain
read-only; install workstation tools manually outside the agent session.
Credentials, shell history, browser profiles, private host data, keys and
environment files are restricted. Approved unrestricted commands and host
daemons can reach beyond these restrictions; review them accordingly.

Codex allows ordinary internet access through its proxy, while local binding,
upstream proxies and control sockets remain restricted. Claude, Cursor and
Copilot use the package-download host policy; Pi's network limits are below.
Nix build/run/develop/store operations require review because they delegate to
the host daemon. Project checks and ordinary non-Nix builds stay sandboxed.

Codex and Claude can read sibling projects under the directory containing this
checkout, with secret-file restrictions. Claude may still ask before accessing
a sibling repository; launch with `--add-dir` when it belongs in the session.
T3 Code's caches, attachments, browser artifacts and worktrees are readable;
its database, provider secrets, sign-in cache, provider registry and service
environment stay denied. A host can also pass content directly to the model.

Git over SSH and `fj` need keys, the SSH agent socket or a stored token, so
fetches, pushes and Forgejo calls to such remotes run as approved commands
outside the sandbox. A Claude `allowed_domains` entry does not help: SSH
bypasses the sandbox proxy. Use HTTPS for public fetches. Claude runs `fj`
like `gh`: read-only views run without prompting and everything else asks.
When a task writes to a sibling repository, add it to the session (`/add-dir`
or `--add-dir`) instead of escaping. `git worktree add`, `move` and `remove`
for worktrees other than the session's own write the main repository's Git
metadata and need an approved run outside the sandbox.

For this repository's validation rules, use [AGENTS.md](../../AGENTS.md).

## T3 Code permission modes

Choose **Auto-accept edits** for Codex and Claude to keep sandbox escapes
reviewed by you. Set the default under **Settings → Threads → New threads →
Permissions**, and change existing threads separately. **Auto** uses automatic
review; **Full access** removes the ordinary approval boundary. T3 injects its
own MCP endpoint and allows its Claude tool namespace; Codex tool-specific
prompts remain separate from shell approvals. See [T3 permission modes](https://github.com/pingdotgg/t3code/blob/main/docs/user/permission-modes.md).
Provider binary paths are set once during
[new Mac setup](../runbooks/new-mac.md#after-the-first-activation).

Sandboxed Pi cannot reach T3's local MCP endpoint or escape after approval.
Run blocked operations manually or use Codex/Claude; see [Pi's limits](#pi).

## Worktrees

| Client | Managed location or launch requirement |
| --- | --- |
| Codex | `~/.codex/worktrees`, including worktrees created during a session |
| Claude | `<repo>/.claude/worktrees`, with shared Git metadata granted |
| Copilot | `<repo>.worktrees/` |
| Cursor | `~/.cursor/worktrees` and its relocated config's `worktrees` directory |
| OpenCode | Active worktree is part of the selected project |
| Pi | Launch inside the worktree; there is no global managed-worktree grant |

Git metadata needs write access for commits; hooks and config remain protected.
Codex's shell wrapper grants linked-worktree metadata. App launches bypass the
wrapper: this repository has a persistent grant, while other repositories may
need an explicit metadata-directory grant and a fresh session. Moving a worktree
to `/tmp` does not grant writes to its original shared Git directory.

## Pi

Launch `pi` from the project root. Safehouse covers Pi, extensions, MCP servers
and child commands. Writes are limited to the project, scratch space, Pi state
and agent caches; project `.pi` files, Git hooks/config, permission settings and
installed extension code remain protected. Launching from home or `/` grants
an empty workspace. Clipboard integration is enabled.

Confirm the pinned permission extension loads without errors; inspect it with
`/permission-system show`. Routine file tools, bash and the configured web
research tools are allowed. Installs, publishing, remote writes, host control,
Nix daemon operations, shell wrappers and uncertain commands ask. Unknown tools
and MCP calls also ask. Only load trusted extensions: they share Pi's process
access, including its stored login. Prefer a provider key passed through the
environment when possible. The installed npm package directory remains writable.

Pi permits internet access without a domain allowlist. Host-local TCP/UDP services
and UNIX sockets are blocked, except system DNS; other LAN hosts remain reachable.
Local development servers and T3's local MCP endpoint are therefore unavailable.
An approval cannot grant a socket or escape Safehouse. Run blocked operations
manually outside Pi or use Codex/Claude's approved escape flow; do not retry
through Rex or `pi-unsandboxed`.

Web search returns raw results, with browser launches and cookie extraction
disabled. `/curator off` closes the optional review UI.

## Terminal and VM control requires review

Rex, Kitty and Incus delegate to host services. Execution, input injection,
terminal capture and VM changes require review. Some clients allow narrow
help/listing calls; Codex asks for every invocation in these families, and
Claude asks for every Rex invocation, including help and listings.

Claude excludes Rex from its Bash sandbox; exclusion selects unsandboxed
execution but does not grant approval. Codex uses its native approved retry.
Keep control endpoints out of sandbox socket/network grants. If an approved
retry still fails, report it rather than widening socket access.

## Diagnose blocked commands

| Error | Action |
| --- | --- |
| `Operation not permitted` | Check the path and active grants; use workspace/temp for scratch files |
| `403`, `Forbidden`, `CONNECT tunnel failed`, or host not allowlisted | Check whether sandbox policy blocked the host; request scoped approval if needed |
| Go `x509: OSStatus -26276` | macOS trust-service access may be blocked; request an approved retry |
| Node OpenSSL configuration read failure | Codex grants `/System/Library/OpenSSL`; apply and restart if the grant is missing |
| `device not configured` on `/dev/tty` | Use non-interactive flags |

Retry a confirmed sandbox failure once with escalation where supported; Pi
cannot escalate. Explicit secret-file denies remain off-limits. Do not loop
through variants, move credentials or disable TLS verification.

Nixpkgs-built Go tools use the configured CA bundle; upstream binaries may still
need escalation. Claude adds the Nix bundle to system certificates. Codex adds
it through `NODE_EXTRA_CA_CERTS` and sets `NODE_USE_SYSTEM_CA=0`; an explicit
`--use-system-ca` flag can still trigger sandbox warnings. Private CA overrides
must preserve the required public roots.

To change the policy, edit the [shared policy](../design/agent-permissions.md#one-policy-one-adapter-per-client)
rather than a single client's adapter.
