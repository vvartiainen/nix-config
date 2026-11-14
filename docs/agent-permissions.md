# Agent permissions and sandboxes

The OS sandbox limits routine commands; approval allows reviewed actions beyond
it. Active session policy is authoritative. Skills and MCP availability do not
grant filesystem or command access.

## Client behavior

| CLI | Routine work | Approval boundary |
| --- | --- | --- |
| Codex | Workspace commands run sandboxed | Explicit ask rules and sandbox escapes; all Rex/Kitty/Incus calls prompt because prefix rules cannot carve out safe exceptions |
| Claude Code | Workspace edits and commands run sandboxed | Native ask rules plus a shell hook for host control; Rex runs unsandboxed with approval; scoped `gh` inspection runs outside the sandbox |
| Cursor | Workspace commands run sandboxed in Allowlist mode | Shell hook asks for risky operations and unsandboxed retries; narrow host metadata allowances remain available |
| Copilot | Inspection, scoped development runners and file edits are approved | Unlisted commands and sandbox bypasses ask; `just lint` is scoped, other `just` recipes ask |
| OpenCode | Inspection allowlist and workspace file tools | No OS sandbox: project runners, cleanup commands and unknown shell commands ask |
| Pi | Whole process runs in Safehouse; file tools, bash and named web research tools run without prompts | Risky commands and unknown/MCP tools ask; approvals remain inside Safehouse |

The shared policy distinguishes inspection, sandboxed development, reviewed
operations and hard denies. Project runners and tools with execution options
(`rg --pre`, `find -exec`, `sed`, `awk`) are only automatically approved behind
an OS sandbox. Local edits, commits and workspace cleanup are routine work;
there is no blanket `rm` ban. Copilot has no per-command ask override, so it
does not get a broad `just` allowance that would also approve `just switch`.

Installs, package publishing, Git pushes, remote mutations, privileged commands,
system application and host control require review. Credential extraction and
recognizable disk-erasure, force-push, hard-reset and forced Git-clean commands
are denied. Reordered flags are covered where the client's patterns or hook can
express them. Prefix-only clients cannot recognize every spelling or commands
hidden inside scripts. These rules prevent accidental approvals; they do not
replace filesystem and network isolation.

Keep sandboxing enabled. Persistent broad command approvals can weaken these
defaults. In Copilot, use `/reset-allowed-tools` to clear old broad grants before
testing changed rules. Start fresh sessions after permission changes.

Codex can read and write its managed checkouts under `~/.codex/worktrees`,
including worktrees created during a session. Secret-file denies still apply
there; their Git hooks/config stay in the main checkout's read-only Git dir.
Other Codex state retains its existing permissions. Apply permission changes manually and start a fresh session.

Like Claude, Codex can read sibling projects under the directory containing
this checkout, with environment files and keys denied throughout that directory.
Writes remain scoped to its workspace, managed worktrees, scratch space and
agent caches. Ordinary local Git rebases, resets and cleanup use the sandbox
without an extra command prompt; destructive variants still have deny rules.
The shell launch wrapper grants a linked worktree's shared Git metadata while
keeping hooks and config read-only. This repository's shared Git metadata also
has a persistent grant for app launches, which bypass that wrapper. Other
repositories launched through an app still need an explicit metadata directory
grant and a fresh session. Moving a worktree to
`/tmp` does not grant writes to its shared Git metadata in the original repo.

Claude CLI worktrees live under the repository's `.claude/worktrees`; Claude
also grants their shared Git metadata. Copilot starts worktree sessions inside
`<repo>.worktrees/`. OpenCode treats its active worktree as part of the project.
These use the selected workspace rather than a global worktree-directory grant.
Cursor explicitly allows `~/.cursor/worktrees` and the relocated CLI config's
`worktrees` directory. Pi has no configured managed worktree root: launch it
inside a worktree; its wrapper grants the linked Git metadata for that launch
while keeping Git hooks/config protected and the main checkout's sources outside
the write grant.

## Pi

Start `pi` inside the project directory. Its Nix wrapper runs Pi, extensions and
child commands in [Safehouse](https://agent-safehouse.dev/). Writes are limited
to the invocation directory, scratch space, Pi state and shared agent caches;
unrelated home files and the shared secret paths remain restricted. Project
`.pi` files, Git hooks/config and the global permission settings are protected
from writes. Launching from home or `/` uses an empty workspace grant instead
of granting that directory. Launch from a repository
root when the task needs the whole repository. Safehouse's clipboard
integration is enabled, so `pbcopy`/`pbpaste` and Pi's copy/paste work without
widening file access.

The pinned `@gotgenes/pi-permission-system` package installs on first launch,
like the other Pi packages. Confirm it loads without extension errors; use
`/permission-system show` to inspect its rules. Routine file tools and bash run
without prompts because Safehouse is the boundary and path rules still deny
secrets. The pinned web extension's `web_enable`, `web_search`, `source_check`,
`fetch_content` and `get_search_content` tools are also allowed by name. Unknown
extension tools and MCP tools still ask; there is no global tool allowance or
YOLO mode. The extension asks for installs, publishing, remote writes, host control
and Nix daemon operations, for shell wrappers such as `sh -c`, `eval`, `sudo`,
`xargs` and `find -exec`, and for unparseable input. Credential extraction and
destructive-command denies still apply.
Narrow host metadata and help rules are allowed, though socket access may still
fail inside Safehouse. Permissions are an approval layer, not a security boundary: trusted project configuration and extensions
can affect their behavior. Do not load untrusted extensions or disable the
permission package.

Web search defaults to raw results (`workflow = "none"`), with automatic browser
launches and browser-cookie extraction disabled. Activation merges these defaults
into `web-search.json`, preserving provider keys and unrelated user settings.
The curator is a separate review UI, not a permission boundary; `/curator off`
disables it again if enabled interactively. Apply the configuration manually and
start a fresh Pi session to pick up these changes.

The sandbox also denies writes to extension code under Pi state (except the
permission extension's review log) and to the user-level `mcp.json`, so a session
cannot persist code or servers for a later one. The wrapper resolves PATH entries
to the directories they link to before launch, so Home Manager tools such as
`statix`, and MCP servers configured by name such as `mcp-nixos`, start
inside Pi; the profile symlinks themselves stay outside the read grants.

Safehouse permits public IP networking for research and provider APIs. The
wrapper denies outbound connections to host-local IP services (TCP and UDP,
IPv4 and IPv6) and UNIX sockets, except the system DNS resolver socket. These
denials apply to Pi, extensions, MCP servers and child commands. Seatbelt's
`localhost` selector cannot filter arbitrary private-network ranges: other LAN
hosts remain reachable. Enforcing public-only destinations would need a separate
filtering proxy and a sandbox rule forcing all traffic through it. There is no
domain allowlist or prevention of exfiltration of readable data.

An approval does not escape Safehouse or grant a socket. Run blocked Nix builds
and host-service operations manually outside Pi; do not retry through Rex,
`pi-unsandboxed`, another interpreter or a newly allowed socket. This also blocks
local development-server clients and local MCP endpoints, including T3's local
MCP endpoint in sandboxed sessions. Pi must read its own stored credentials;
tool-level rules deny `auth.json`, but extensions share Pi's process access and
the path deny is exact, so a recursive read of the agent directory or a program
that computes the path still reaches it. Prefer provider keys passed through the
environment over stored logins: the wrapper passes `DEEPSEEK_API_KEY` when set
and otherwise sanitizes the environment, and existing stored provider logins
remain usable. The installed npm package directory stays writable: a blocked
write makes Pi skip a package instead of failing, so vendoring the pinned
packages is open work. MCP servers started by Pi inherit these limits too;
servers using data outside the granted paths need a separately reviewed grant
before they can work.

## Working in the sandboxes

- Host apps share state with the CLIs they run. T3 Code's cache, thread
  attachments, browser artifacts and worktrees are readable in every sandbox
  that has a path allowlist; its thread database, provider secrets, sign-in
  cache, provider server registry and `service.env` stay denied. The host can
  still pass a readable path to the model: a sandbox bounds what a command
  reaches, not what the host already shares.

- Write in the workspace, `$TMPDIR`, `/tmp`, or `~/.cache/<tool>-agent`.
  Package cache variables already point there; do not redirect them.
- Codex allows ordinary internet access while retaining filesystem restrictions
  and command approvals. Local binding, upstream proxies and control sockets
  remain restricted. Other clients use the package-download host allowlist or
  their documented network policy.
- Git status, diff, add and commit work. Hooks and Git config are protected
  where supported to keep them from becoming an escape route.
- Normal caches and tool installations stay read-only. Install tools manually
  outside the agent session; use non-interactive commands for agent checks.
- Credential files, shell history, browser profiles, private host data, keys
  and environment files are restricted. Do not work around a denied read.

Codex and Claude run routine project checks and builds inside their sandbox
without per-command approval. Nix build/run/develop/store operations require
review because they delegate work to the host daemon. Package installation and
remote mutation commands also ask. Copilot allows scoped development runners;
OpenCode asks for them because it has no OS sandbox.

The Claude and Cursor shell hooks add review and deny decisions; routine calls
continue through the native permission and sandbox flow. Cursor's hook also asks
for shell syntax and wrappers it cannot see through and when sandbox metadata is
missing. Claude's hook looks through redirects, substitutions, `sh -c` and
wrappers and asks only when a part matches a review, deny or host rule. Hook errors return a valid denial instead of relying on a
client's potentially fail-open exit-code handling.

Claude's hook skips quoted heredoc bodies, which are literal input rather than
shell commands. It still checks the command receiving that input and commands
after the heredoc. Unquoted bodies remain subject to review because they can
expand shell commands. Native Claude permission checks can still prompt.
For example, Claude asks before read-only Git commands in sibling repositories
unless the session was started with `--add-dir` for them.

Claude's Code Mode is enabled for terminal sessions. Tool calls from its
scripts still go through deny and ask rules, the shell hook and the sandbox.

For nix-config, follow [AGENTS.md](../AGENTS.md): validate against the public
fixture, never read private host data for routine checks, and never apply the
fixture system. The user validates and applies real host configuration manually.

## Terminal and VM control requires review

Rex, Kitty and Incus can execute commands through host services with the user's
permissions. Their execution, input injection, terminal-content capture and
VM-changing operations require approval rather than a blanket command ban.
Help/version and selected session/instance listings are allowed where the
client can express a narrow exception. Reading terminal contents and dumping
configuration remain reviewed operations because they can disclose secrets.

Keep control endpoints out of sandbox socket/network allowlists. A metadata
command may still need approval to reach its service; Pi cannot escape
Safehouse after approval. Codex prompts for every invocation in these command
families because a broad prompt prefix overrides narrower allowances.

Claude excludes Rex from its Bash sandbox and asks for each invocation, including
help and listings. Exclusion selects unsandboxed execution; it does not grant
approval. Codex uses its native approved unsandboxed retry. Do not save a blanket
Rex approval. If the host still blocks an approved retry, report the failure
rather than granting the control socket inside the sandbox.

Secret-file denies apply to file tools and sandboxed commands where supported.
They cannot contain an approved unrestricted command or a host daemon acting
on its behalf. OpenCode's file rules and shell scanner are best effort, not OS
isolation. Review escapes as full-access operations and avoid broad persistent
approvals. Existing provider-authentication and trusted-extension exceptions
remain, including Pi's stored-login limitation described above.

## Diagnose blocked commands

| Error | Action |
| --- | --- |
| `Operation not permitted` on write | Check the writable paths; use workspace/temp for scratch files |
| `403`, `Forbidden`, `CONNECT tunnel failed` | Request approval for the blocked host |
| `x509: OSStatus -26276` | macOS Go TLS cannot reach trustd; request an approved retry outside the sandbox |
| `device not configured` on `/dev/tty` | Use non-interactive flags |

Retry once with escalation when the error identifies the sandbox. Do not loop,
disable TLS checks, move credentials, or disguise commands to evade rules.
Nixpkgs-built Go tools honor the configured certificate bundle; upstream Go
binaries may still need escalation. Claude keeps the system certificate store
plus the Nix CA bundle; a private CA override must include both private and Nix
roots.

Codex grants read access to `/System/Library/OpenSSL` for Node startup and adds
the Nix CA bundle through `NODE_EXTRA_CA_CERTS`. `NODE_USE_SYSTEM_CA=0` avoids
opting into macOS trust-store lookups through the environment. An explicit
`--use-system-ca` flag can still request those lookups and produce sandbox
warnings. TLS verification remains enabled.

Shared policy is in [permissions.nix](../nix/modules/home/programs/ai/shared/permissions.nix);
each CLI module renders its own adapter.
