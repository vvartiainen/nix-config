# Agent permissions and sandboxes

The guidelines behind this policy are in
[design/agent-permissions](../design/agent-permissions.md).

Active session policy is authoritative. Apply configuration changes manually
and start fresh sessions. For provider-specific mode choices in T3 Code, see
[T3 Code permission modes](#t3-code-permission-modes).

## Client behavior

The [agent comparison](comparison.md) shows what each client runs, asks about
and denies, and which one to pick.

Command rules supplement the sandbox; OpenCode's are best effort without OS
isolation. In Copilot, use `/reset-allowed-tools` to clear old broad grants
before testing changed rules. Claude's Code Mode retains the normal permission,
hook and sandbox checks.

## Working in the sandboxes

The configured terminal sandboxes allow writes in the workspace, `$TMPDIR`,
`/tmp` or `~/.cache/<tool>-agent`. T3 Codex uses its active managed writable
roots instead; a cache environment variable is not a filesystem grant. Preserve
the configured cache variables. Normal caches and tool installations remain
read-only; install workstation tools manually outside the agent session.
`XDG_CACHE_HOME` points to `~/.cache/xdg-agent`, so tools without their own
cache variable, such as treefmt, uv and pre-commit, cache there. Under T3 it
stays `~/.cache` for Claude and Codex, although the other cache variables
apply; such tools can then fail with `Operation not permitted`.
For Claude, set the tool's own cache variable to an allowed agent-cache path.
For T3 Codex, check the active roots before selecting a cache path; even
`NIX_CACHE_HOME=~/.cache/nix-agent` can fail opening `fetcher-locks/*.lock`.
Use a reviewed retry for Nix or a terminal session with the configured profile.
A scratch cache does not grant Nix daemon access.
Credentials, shell history, browser profiles, private host data, keys and
environment files are restricted. Approved unrestricted commands and host
daemons can reach beyond these restrictions; review them accordingly.

Terminal Codex allows ordinary internet access through its proxy, while local binding,
upstream proxies and control sockets remain restricted. Claude, Cursor and
Copilot use the shared package/source host policy; Pi's network limits are below.
Claude's WebSearch and WebFetch tools are approved by a `PreToolUse` hook, not
`WebFetch(domain:…)` allow rules, because those rules would also open the
domains to sandboxed Bash. The shell allowlist includes the exact hosts
`api.github.com` and `raw.githubusercontent.com` for routine API/source requests
and downloads. It grants every path and supported HTTP method on those hosts,
including API uploads with supplied credentials. GitHub web, archive and release
redirect hosts remain unlisted; redirects to them need review. No GitHub
wildcard is allowed. These settings do not override T3 Codex's managed policy.
Nix build/run/develop/store operations require review because they delegate to
the host daemon; project checks stay sandboxed unless they run Nix, as this
repository's `just check` and `just build` do.
Unix sockets are blocked except the Nix daemon socket and
`~/.cache/tofu-agent`, where `PLUGIN_UNIX_SOCKET_DIR` puts Terraform and
OpenTofu provider sockets, so `validate` with providers runs sandboxed. Only
commands from agent sessions listen there, approved unsandboxed runs included;
their provider connections use per-run TLS. Symlinks to other sockets are
checked at their target, so Rex, the SSH agent and 1Password stay blocked. In
T3, Codex's per-turn sandbox does not include this grant.

Codex and Claude can read sibling projects under the directory containing this
checkout, with secret-file restrictions. Claude may still ask before accessing
a sibling repository; launch with `--add-dir` when it belongs in the session.
T3 Code's caches, attachments, browser artifacts and worktrees are readable;
its settings, database, provider secrets, sign-in cache, provider registry and
service environment stay denied in the configured terminal profiles. Settings
can contain literal provider environment values or custom provider configuration;
redaction of recognized credential fields is not a guarantee for the whole file.
Inspect declared settings in the Nix module instead. T3 Codex supplies its own
read policy, so these denies do not automatically carry over. A host can also
pass content directly to the model.

Git over SSH needs a key or the SSH agent socket. Pi's sandbox reads
`~/.ssh/config` and `known_hosts` and reaches the socket a host app exports, so
`ssh`, `scp`, `rsync` and SSH remotes work there when the agent holds the key;
key files stay unreadable and other sockets stay blocked. Claude and Codex run
SSH, pushes and forge calls outside the sandbox after review. Pi also reaches the
forge over HTTPS with an agent-only token and a wrapper that shadows `fj` inside
its sandbox. Its routine `git fetch origin`, branch push and pull-request
create/edit run without a prompt; other remotes, force and destructive remote
forms, merges and issue writes ask. Claude and Codex run read-only `gh`
and `fj` views without prompting, and Claude does the same for `git fetch` from
a configured remote. A Claude
`PreToolUse` hook reads `git remote` in the command's `cwd` without writing
config. It defers for standalone `git fetch` with only known option flags,
configured remote names followed by refspecs, `--all`, and
`--multiple`/`--prefetch` with only configured remotes. Configured remotes
remain trusted, including file URLs, `insteadOf` rewrites and `ext::`/transport
commands configured in Git config. Explicit URLs, scp-style addresses, paths,
unknown names, `--upload-pack`/`-u`, unknown options, tilde syntax (even quoted),
noncanonical whitespace, unclassified shell syntax and remote-read failures
return `ask`. The fetch handler requires Claude Code
2.1.295 or later: [`onFailure: "block"`](https://code.claude.com/docs/en/hooks#block-the-action-when-a-hook-fails)
blocks every Bash call if the fetch hook crashes, cannot start or times out.
The hook ignores commands without both `git` and `fetch` words and plain
`git log` searches; ambiguous literals such as `rg 'git fetch' docs/` still ask.
Claude's [`if` filter](https://code.claude.com/docs/en/hooks#common-fields)
uses best-effort permission patterns, with no documented candidate-only rule
covering every wrapped, quoted and compound fetch spelling, so this hook keeps
the broad `Bash` matcher to preserve review coverage. The existing
fetch ask patterns remain as defence in depth. Per Claude's
[hook decision documentation](https://code.claude.com/docs/en/hooks#pretooluse-decision-control),
`ask` prompts even when an allow rule matches; hooks run before every tool call.
[Sandbox exclusions](https://code.claude.com/docs/en/sandboxing#run-commands-outside-the-sandbox-with-excludedcommands)
still use that permission flow. Codex asks for every fetch. These rules match only standalone
commands: with `cd`, pipes, loops, `-C` or `-H` the command runs sandboxed and
fails (`fj` reports `Operation not permitted` from its keychain), or prompts.
`fj pr edit <n> body` and `fj issue edit <n> body` take the body only as an
argument; `fj-edit-body pr|issue <n> <file>` passes a file's contents instead
of `$(cat ...)` and still asks. `fj pr create`,
`fj pr comment`, `fj issue create` and `fj issue comment` take `--body-file`.
Claude excludes standalone `git push` from the sandbox, so a push asks once
and then runs outside it; force forms stay denied. With `cd`, pipes or `-C` it
runs sandboxed and the proxy refuses the SSH host. A Claude `allowed_domains`
entry does not help: it applies only in auto mode and does not provide the SSH
agent. Use HTTPS for public fetches. Local `git rebase`, `reset` and `clean` run
in the sandbox; their destructive forms are denied. Git config and hooks remain read-only, including
`config.worktree` and settings under `.git/worktrees/`: they can execute
commands during a later unsandboxed Git invocation. Create ordinary branches
with `git switch --no-track -c <branch> origin/main`; the first reviewed push
can still record an upstream.

### Local Git maintenance

Use the installed `agent-git` helper for these standalone commands, from the
repository or one of its linked worktrees:

```sh
agent-git worktree add topic origin/main
agent-git worktree move topic renamed
agent-git worktree remove renamed
agent-git branch -d agent/topic
agent-git branch -m feature/old feature/new
agent-git branch --set-upstream-to origin/main feature/topic
agent-git branch --unset-upstream feature/topic
```

`add` creates branch `agent/<name>` without an upstream, inside the main
checkout's `.agent-worktrees/<name>`. Names contain letters, digits, `_` and
`-`. `move` and `remove` accept only names in that directory; removal retains
Git's dirty and locked worktree checks. Branch deletion uses `-d`, removes its
`branch.*` config section, and refuses a branch checked out in another
worktree. Upstream changes accept plain branch/remote-tracking names only.
Branch rename uses `-m` and updates linked worktree HEADs without overwriting
an existing branch. Other Git operations and arbitrary config changes are rejected.

Claude (terminal and T3) and terminal Codex allow this fixed helper outside
their sandbox without a per-command prompt. It immediately runs pinned Git
in a separate Seatbelt: no network, only pinned Git may execute, no writes
outside Git metadata and `.agent-worktrees`, no hooks or fsmonitor, and no
caller Git configuration environment. Common config is writable only for the fixed
branch operations; checkout filters cannot modify it. Pi's launcher starts
a session-scoped broker outside Safehouse, bound to the launch repository;
inside Pi the same helper sends only operation arguments over its one allowed
Unix socket. This is a fixed maintenance service, not a general sandbox escape.
New worktrees' `config`, `config.worktree` and hooks stay protected in Pi too.
Checkouts requiring external filters, such as Git LFS, need reviewed raw Git.

T3 Codex supplies its own per-turn sandbox and review rules. Workstation Codex
allow rules cannot override those: invoking `agent-git` there may still need
T3 approval. Applying this configuration does not remove that host limitation.
Codex app launches may likewise bypass terminal settings. For normal commits
in terminal linked worktrees, launch through the `codex` zsh wrapper, which
grants the current worktree's index and refs while protecting config.

T3-managed worktrees under `~/.t3/worktrees` remain usable as launch locations;
the helper never removes or moves those paths. Use `git worktree list --porcelain`
and T3's thread list to identify ownership. Do not remove a worktree belonging
to another live thread, even if its branch is merged; let T3 clean up its own
worktrees. Other external worktree locations still require reviewed raw Git
commands. Add a sibling repository to the session (`/add-dir` or `--add-dir`)
before working on it.

For this repository's validation rules, use [AGENTS.md](../../AGENTS.md).

### Forgejo repository discovery

In T3 worktrees with multiple remotes and no branch upstream, `fj` 0.7.0
cannot infer the repository. Keep the allowed subcommand first and include
the host in its repository argument:

```sh
fj pr search -r '<forge-host>/<owner>/<repo>'
fj issue search -r '<forge-host>/<owner>/<repo>'
fj pr view '<forge-host>/<owner>/<repo>#28'
fj pr status '<forge-host>/<owner>/<repo>#28'
fj issue view '<forge-host>/<owner>/<repo>#1'
fj repo view '<forge-host>/<owner>/<repo>'
```

Replace the angle-bracketed placeholders and the PR or issue number. Pi's
sandbox exports `FJ_FALLBACK_HOST` for this instance, so commands there may omit
the host (`fj pr search -r owner/repo`, or `fj pr view owner/repo#28`). These
standalone forms match the existing read-only rules in Claude and Codex; no
apply or upstream write is needed. Writes still ask; see the
[PR workflow](../../AGENTS.md#working-conventions).

[Upstream discovery](https://codeberg.org/forgejo-contrib/forgejo-cli/src/tag/v0.7.0/src/repo.rs)
uses an explicit repository host, otherwise a selected remote (explicit remote,
sole remote, branch upstream, or host-matching remote). It has no configurable
default remote. A fallback host only fills in a missing host for an explicit
repository (`https://` is required; a bare host name is rejected) and never
overrides an inferred one, so a bare `fj pr view <n>` still needs a branch
upstream. Sandboxed pushes cannot record one, which is why every form above
names the repository. Fully qualified arguments avoid discovery ambiguity
without changing Git configuration or allow rules.

## Flake update previews

Agents preview newer pins of the applied configuration with:

```sh
flake-update-preview
flake-update-preview nixpkgs home-manager
```

The installed wrapper accepts only plain input names (excluding `host`) and pins
both the Nix executable and four small store sources: `flake.nix`, `flake.lock`,
`nix/host-unset` and `nix/fixtures/host` from the configuration build. It copies
them into a fresh private directory, rejecting symlinks, and resolves with the
synthetic fixture override. It never reads the working directory's flake or
fixture, builds or applies. Rebuild and apply to preview changed flake definitions.

It atomically replaces `/private/tmp/flake-update-review/flake.lock.new`; the
output directory must be owned by you with mode 0700 and cannot be a symlink.
The repository lock stays untouched. The output restores the embedded lock's
original `host` node (normally `path:./nix/host-unset`), so the fixture does not
appear in lock diffs. Resolution contacts the embedded inputs outside the sandbox
and adds fetched sources to the Nix store.

The shared inspection policy allows this fixed wrapper. Claude excludes it
from the sandbox and allows it without prompting; terminal Codex also allows
it outside the sandbox. Cursor and Copilot retain their sandbox and need an
approved retry for unlisted GitHub download hosts. OpenCode allows it without OS isolation;
Pi cannot reach the Nix daemon. T3's Codex sandbox override can still ask.
Raw `nix flake update` stays reviewed. The API/raw allowances do not cover
GitHub web, archive or release hosts.

The shared network allowlist also includes `pkgs.superlogical.com` and its exact
Rex tarball redirect host, `wthziax2yejsqc4k.public.blob.vercel-storage.com`.
Claude, Cursor and Copilot render this shared list; terminal Codex and Pi already allow
ordinary internet access. No Vercel wildcard is granted. Like any host grant,
the exact host can receive requests from sandboxed commands, so it is limited
to the known download endpoint.

## Secrets

Agents never see secret values; the tool that needs a credential fetches it
itself, outside the sandbox. The forge token below is the deliberate exception,
restricted so that sandboxed pushes and forge calls need no key.

| Need | How | Review |
| --- | --- | --- |
| `gh`, Git over SSH | The tool uses its keychain token or the SSH agent. Pi reaches the agent socket but no key file | Read-only views run without prompting; writes and pushes ask |
| `fj` and forge HTTPS | Agents get their own token in `~/.local/share/agent-forge`, restricted to selected repositories. Pi's sandbox reads it and shadows `fj` with a wrapper that uses it, so sandboxed `git` and `fj` need no key. Your interactive `fj` login is separate | Pushes and forge writes ask, except Pi's [routine forge flow](#pi); revoke the agent token alone if in doubt |
| Provider or cloud credentials, such as `tofu apply` | Approved retry outside the sandbox; 1Password supplies the credential | The agent's approval prompt, then 1Password's |
| A new value only the user has | T3 `request_secret` file delivery, then `op-item-from-secret` | The user enters it; storing asks |

Sandboxed commands cannot read credential files, the keychain or the 1Password
app, apart from the forge token above. A command that needs the others fails,
and the agent asks to retry it outside the sandbox. Approved commands run
without the sandbox's read denies. `op read`,
`op run`, `op inject`, `op item get` and keychain lookups are denied in every
mode: they would put the value in the agent's context or let it run any command
with it. Sandboxes keep exported environment variables and readable workspace
files such as `*.tfvars` or local state; keep secrets out of both. Claude has
no explicit credential-environment filtering configured; Codex sets cache
variables without declaring a credential-variable exclusion list. Pi delegates
environment sanitization to Safehouse and explicitly passes its selected provider
key, cache settings and T3 variables. File denies alone do not prove that an
exported credential is unavailable. Review launch environments separately from
filesystem access; this policy does not guarantee that every secret is hidden.

`op-item-from-secret --vault <vault> --title <title> [--category <category>] [--field <field>] <file>`
stores a `request_secret` file in 1Password. It asks, runs outside the sandbox,
only accepts files under `~/.t3/userdata/secrets`, passes the value to `op` on
stdin, prints only the item's id, title and vault, and deletes the file. Plain
`op item create` with `$(cat <file>)` stays denied: the secret directory is a
Read deny.

## T3 Code permission modes

New threads default to **Auto** for provider automatic review of routine
actions. Choose **Auto-accept edits** for Claude when sandbox escapes should
remain user-reviewed; switch Pi threads to **Full access** by hand in the
composer's permission picker.
T3 supports an environment default and project overrides, but no default per
provider or provider instance. Existing threads and project overrides retain
their selected modes; change those separately in T3. See
[T3 permission modes](https://github.com/pingdotgg/t3code/blob/main/docs/user/permission-modes.md)
and the [settings schema](https://github.com/pingdotgg/t3code/blob/main/packages/contracts/src/settings.ts).

| Provider | Auto-accept edits | Auto |
| --- | --- | --- |
| Claude | Sandboxed workspace, scratch and agent-cache writes, configured-remote fetches and `fj` views run without prompts. Nix builds, unlisted network hosts and reads outside allowed paths ask. | Automatic review can approve Nix builds without prompting. Unlisted hosts fail with `CONNECT tunnel failed, response 403` without a prompt. |
| Codex | Observed shell writes ask, including plain `touch`/`rm` in the workspace and `/tmp`, and every agent-cache write. `git fetch origin` and Nix builds also ask. | Workspace and `/tmp` writes run without prompts; automatic review can approve escalations such as Nix builds. |
| Pi | T3's bridge asks before every tool call it does not classify as read-only, so every shell command, including `rg`, `git status` and `just lint`, prompts even though Pi's own rules allow it. File edits run. | The same per-tool prompts: T3 has no automatic review for Pi. |

T3's Pi bridge decides by tool name, not by command: only `read`, `grep`,
`find`, `ls`, Pi's built-in `tool_search` and read-only MCP tools pass without
asking, and Auto-accept edits adds Pi's file edits. Every other call asks, and
a Pi allow rule cannot suppress the prompt. Run Pi threads in **Full access**,
where no T3 approval is raised and the
[Safehouse sandbox and permission extension](#pi) remain the boundary; a
subagent uses its parent thread's mode.

**Auto** uses provider automatic review; approval requests may still reach you.
**Full access** removes the ordinary approval boundary. T3 injects its own MCP
endpoint and allows its Claude tool namespace; Codex tool-specific prompts
remain separate from shell approvals.

For Pi under **Full access**, no ordinary shell approval reaches you: asks from
Pi's own permission layer are answered inside the session. A command Pi would have asked about then
runs sandboxed and fails where the sandbox blocks it, so `nix build`, `nix
develop`, `nix eval` and anything that runs them, such as `just check`, stop on
the Nix daemon socket with `Operation not permitted`. Pi has no approval path for
Nix in any mode; an approved ask cannot reach the daemon either. Write and lint
the configuration, then run validation yourself or in a Codex/Claude thread.

The default Codex, Claude and Pi provider paths and new-thread permission mode
are merged into `~/.t3/userdata/settings.json` during activation. Close T3 before
applying and restart it afterwards. Other instances and app-managed settings
are preserved; declared values are restored on each apply. Custom T3 home
directories are not managed.

Claude uses `~/.local/bin/claude` and Pi uses the sandboxed executable in the
Home Manager profile. Codex uses the Homebrew CLI with the launch argument
`-c 'default_permissions=":workspace"'` to avoid shell startup failures with
custom permission profiles ([T3 #16458](https://github.com/pingdotgg/t3code/issues/16458)).
Terminal Codex keeps its custom profile. Launch arguments reach the app-server,
but T3 sends its own `sandboxPolicy` on every turn, so selecting a modified
profile through `-c default_permissions=...` does not make it authoritative.
In Auto, T3 sends `workspaceWrite` and selects the automatic approvals reviewer.
Custom profiles with a root deny have reported macOS shell failures with this
override. Keep the built-in profile workaround until T3 supports
[profile inheritance](https://github.com/pingdotgg/t3code/discussions/6976);
see the [Codex adapter](https://github.com/pingdotgg/t3code/blob/main/apps/server/src/orchestration-v2/Adapters/CodexAdapterV2.ts).
No separate launcher or Codex home is needed.

T3's Codex sandbox differs from the terminal profile
([T3 discussion #6976](https://github.com/pingdotgg/t3code/discussions/6976)).
Terminal network, cache and shared Git metadata grants do not transfer to
the managed per-turn policy; inspect the active tool permissions. Changing
`network.sandbox` cannot enable T3 Codex networking.
Do not rely on the terminal profile's secret-file denies in T3. Claude keeps
its own sandbox settings under T3.

Sandboxed Pi reaches T3's local MCP endpoint, so its T3 tools and the thread's
runtime mode work; no approval can reach any other host service or leave the
sandbox. Run that blocked work manually or use Codex/Claude; see
[Pi's limits](#pi).

## Development expectations

| Requirement | Configured behavior and limits |
| --- | --- |
| Work in an agent's own checkout | Terminal clients support their launch worktree. In T3, attach each thread to its own worktree. Claude and Pi keep their configured sandbox; T3 Codex may need reviewed Git metadata writes for staging and commits. |
| Ordinary internet access | Terminal Codex and Pi allow arbitrary internet hosts. Claude, Cursor and Copilot retain the shared package/source host list; Claude web research runs freely, while unlisted shell downloads need review. T3 Codex networking is host-managed and may require escalation. |
| Keep credentials private | Terminal profiles deny known credential paths and secret file patterns. This does not cover every secret in project files, inherited environment variables, tool output or approved host-side commands. T3 Codex's built-in profile does not inherit these denies. Use a configured terminal profile when those filesystem restrictions are required; Full access does not restore them. |

Worktrees separate source edits, not all agent capabilities: clients can read
shared artifacts and some permit writes to managed worktrees or shared refs.
Keep secrets out of readable workspaces and launch environments. Pi's forge token
and selected provider key remain deliberate exceptions described in [Secrets](#secrets).

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

Git and `fj` reach the forge over HTTPS with the
[restricted agent token](#secrets): the sandbox puts a `fj` wrapper first on
`PATH` that reads a token from `~/.local/share/agent-forge`, exports
`FJ_FALLBACK_HOST`, and a generated Git
config rewrites that instance's SSH remotes and answers credential requests from
the same file. SSH works too: `~/.ssh/config` and `known_hosts` are readable and
the selected agent socket is reachable, while key files, your interactive `fj`
login, the keychain and the rest of 1Password stay unavailable. Pi uses the
declared workstation `SSH_AUTH_SOCK` when configured, otherwise the host app's
inherited value. The same value selects the sandbox grant and child environment;
a GUI app's different launchd socket is not also granted. Agent access permits
authentication with keys the agent offers, which can reach beyond the token's
repository restrictions. The agent must already hold the key,
and a new host key cannot be stored from the sandbox, so connect once outside
Pi before using a new host. Create or rotate the token with the
[forge token runbook](../../runbooks/forge-token.md).

System SSH includes can resolve through nix-darwin's `/etc/static` symlink:
Pi grants metadata-only traversal of that symlink into the already-readable
Nix store. This does not grant recursive reads of `/etc/static` or key files.

Git works as in a terminal, including `git init` and `git clone` in the project
or scratch space. The launch checkout's git directories keep `config`,
`config.worktree` and `hooks` read-only in both ordinary and linked checkouts,
so sandboxed code cannot instrument a
later unsandboxed `git` run; a linked worktree's `.git` pointer file is
read-only for the same reason. `git push -u` therefore pushes the branch but
cannot record its upstream: Git prints `error: could not write config file
.../.git/config` twice and still reports the branch as tracking, so inspect the
remote ref before assuming success. Push with `git push origin <branch>`, and
give `fj` a
repository argument. Where an upstream is genuinely needed, record it with
`agent-git branch --set-upstream-to origin/<branch> <branch>` ([local Git
maintenance](#local-git-maintenance)); a reviewed `git push -u` outside the
sandbox records it too. Both push forms run without a prompt; other remotes and
the guarded push forms still ask.

Confirm the pinned permission extension loads without errors; inspect it with
`/permission-system show`. Routine file tools, bash, tool discovery and the
configured web research tools are allowed. So is the forge flow this repository
needs on every task: `git fetch origin` (also with `--prune`, `--quiet` or `-q`
before the remote), branch pushes to `origin` and
`fj pr create`/`fj pr edit` run without a prompt. Force pushes stay denied, and
other remotes, remote branch deletion or mirroring, direct `main`/`master`
pushes, merges, issue writes, installs, publishing, credentials, host control,
shell wrappers and uncertain commands ask. Unknown tools and other MCP calls
also ask; T3's own tools do not, because the endpoint it injects gates them
with the thread's runtime mode.
Nix is different: every command that reaches the daemon socket fails with
`Operation not permitted`, and no approval can grant it. Write and lint Nix
configs, then ask the user to evaluate or build with the
[fixture commands](../../AGENTS.md#validation-commands-no-apply). Only load trusted extensions: they share Pi's process
access, including its stored login. Prefer a provider key passed through the
environment when possible. The installed npm package directory remains writable.

Pi permits internet access without a domain allowlist. Host-local TCP/UDP services
and UNIX sockets are blocked, except system DNS, the loopback port of a host
app's injected tool endpoint (`T3_MCP_URL`) and the selected SSH agent socket;
other LAN hosts remain reachable. Local development servers are
therefore unavailable and only those host connections are reachable, never
another port or socket on the host.
The host-local selector matches assigned host addresses, not every address in
`127.0.0.0/8`. On macOS an unassigned loopback-looking address can route off-host;
do not treat this rule as a private-network allowlist. Runtime tests bind their
own listeners and skip addresses the Mac cannot bind.
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
| `Operation not permitted` | Check the path and active grants; use workspace/temp for scratch files. In a T3 Code thread running Pi under Full access, asks are answered inside the session, so Nix daemon work fails here without a prompt |
| `could not write config file …/.git/config` after a push | The upstream write was blocked; this alone does not prove the remote push succeeded. Confirm with `git ls-remote origin <branch>` and continue without `-u` |
| `curl: (6) Could not resolve host` | May be DNS or sandbox network policy; success of the exact approved retry supports the latter, not a new host grant |
| Nix `fetcher-locks/*.lock` denied | Check active writable roots, especially T3 Codex; inherited `NIX_CACHE_HOME` is not a grant |
| Ignored SQLite eval-cache busy warning | Avoid concurrent evaluated-option probes; serialize if results are affected, without changing permissions |
| SSH `sign_and_send_pubkey` / `communication with agent failed`, then `Too many authentication failures` | Authentication failure; one exact reviewed retry may resolve a transient failure. Persistent failure needs user diagnosis outside the agent; do not open credential paths |
| `rg --files /nix/store` hits a transient directory | Narrow the search to the known derivation output or artifact glob; do not grant more store access |
| `403`, `Forbidden`, `CONNECT tunnel failed`, or host not allowlisted | Check whether sandbox policy blocked the host; request scoped approval if needed |
| Go `x509: OSStatus -26276` | macOS trust-service access may be blocked; request an approved retry |
| Node OpenSSL configuration read failure | Codex grants `/System/Library/OpenSSL`; apply and restart if the grant is missing |
| `device not configured` on `/dev/tty` | Use non-interactive flags |

Retry a confirmed sandbox failure once with escalation where supported; Pi
cannot escalate. Explicit secret-file denies remain off-limits; see
[Secrets](#secrets). Do not loop through variants, move credentials or disable
TLS verification.

For a stalled push, prefer the command session's status/output. If process
inspection is needed, review a query for known process IDs, for example
`ps -p <pid> -o pid=,ppid=,etime=,stat=,comm=`. Avoid full argument dumps:
`ps -axo ...command | rg ...` reads every process's arguments before filtering
and can expose tokens or private paths. Do not save an unfiltered dump or
grant unrestricted `ps` just to suppress the prompt.

Nixpkgs-built Go tools use the configured CA bundle; upstream binaries may still
need escalation. Claude adds the Nix bundle to system certificates. Codex adds
it through `NODE_EXTRA_CA_CERTS` and sets `NODE_USE_SYSTEM_CA=0`; an explicit
`--use-system-ca` flag can still trigger sandbox warnings. Private CA overrides
must preserve the required public roots.

To change the policy, edit the [shared policy](../design/agent-permissions.md#one-policy-one-adapter-per-client)
rather than a single client's adapter.
