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

Write in the workspace, `$TMPDIR`, `/tmp` or `~/.cache/<tool>-agent`. Preserve
the configured cache variables. Normal caches and tool installations remain
read-only; install workstation tools manually outside the agent session.
`XDG_CACHE_HOME` points to `~/.cache/xdg-agent`, so tools without their own
cache variable, such as treefmt, uv and pre-commit, cache there.
T3's managed Codex, Claude, OpenCode and Pi instances set it in their
[provider environment](https://github.com/pingdotgg/t3code/blob/main/packages/provider-core/src/server/instanceEnvironment.ts)
before the client starts, overriding the inherited normal-shell
cache. These instances' environment lists are managed by Nix; declare any extra
variables there too. Normal shells keep their usual cache. After applying,
restart T3, open new Claude and Codex threads and run `printenv XDG_CACHE_HOME`
in each; expect `~/.cache/xdg-agent` expanded to your home directory.
Credentials, shell history, browser profiles, private host data, keys and
environment files are restricted. Approved unrestricted commands and host
daemons can reach beyond these restrictions; review them accordingly.

Codex allows ordinary internet access through its proxy, while local binding,
upstream proxies and control sockets remain restricted. Claude, Cursor and
Copilot use the package-download host policy; Pi's network limits are below.
Claude's WebSearch and WebFetch tools are approved by a `PreToolUse` hook, not
`WebFetch(domain:…)` allow rules, because those rules would also open the
domains to sandboxed Bash.
Nix build/run/develop/store operations require review because they delegate to
the host daemon. Project checks and ordinary non-Nix builds stay sandboxed.
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
its database, provider secrets, sign-in cache, provider registry and service
environment stay denied. A host can also pass content directly to the model.

Git over SSH and `fj` need keys, the SSH agent socket or a stored token, so
fetches, pushes and Forgejo calls to such remotes run outside the sandbox.
Pushes and forge writes ask. Claude and Codex run read-only `gh` and `fj`
views without prompting, and Claude does the same for `git fetch` from a
configured remote; fetches naming a URL, a local path or `--upload-pack` still
ask, and Codex asks for every fetch. These rules match only standalone
commands: with `cd`, pipes, loops, `-C` or `-H` the command runs sandboxed and
fails (`fj` reports `Operation not permitted` from its keychain), or prompts.
`fj pr edit <n> body` and `fj issue edit <n> body` take the body only as an
argument; `fj-edit-body pr|issue <n> <file>` passes a file's contents instead
of `$(cat ...)` and asks like other forge writes. `fj pr create`,
`fj pr comment`, `fj issue create` and `fj issue comment` take `--body-file`.
A Claude `allowed_domains` entry does not help: SSH bypasses the sandbox proxy.
Use HTTPS for public fetches. Local `git rebase`, `reset` and `clean` run in
the sandbox; their destructive forms are denied. Sandboxed Git
does not record a new branch's upstream, because `.git/config` is protected;
the first push sets it.
When a task writes to a sibling repository, add it to the session (`/add-dir`
or `--add-dir`) instead of escaping. `git worktree add`, `move` and `remove`
for worktrees other than the session's own write the main repository's Git
metadata and need an approved run outside the sandbox.

For this repository's validation rules, use [AGENTS.md](../../AGENTS.md).

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
approved retry for GitHub downloads. OpenCode allows it without OS isolation;
Pi cannot reach the Nix daemon. T3's Codex sandbox override can still ask.
Raw `nix flake update` stays reviewed. GitHub is not added to sandboxed Bash.

The package download allowlist includes `pkgs.superlogical.com` and its exact
Rex tarball redirect host, `wthziax2yejsqc4k.public.blob.vercel-storage.com`.
Claude, Cursor and Copilot render this shared list; Codex and Pi already allow
ordinary internet access. No Vercel wildcard is granted. Like any host grant,
the exact host can receive requests from sandboxed commands, so it is limited
to the known download endpoint.

## Secrets

Agents never see secret values; the tool that needs a credential fetches it
itself, outside the sandbox.

| Need | How | Review |
| --- | --- | --- |
| `gh`, `fj`, Git over SSH | The tool uses its keychain token or the SSH agent | Read-only views run without prompting; writes and pushes ask |
| Provider or cloud credentials, such as `tofu apply` | Approved retry outside the sandbox; 1Password supplies the credential | The agent's approval prompt, then 1Password's |
| A new value only the user has | T3 `request_secret` file delivery, then `op-item-from-secret` | The user enters it; storing asks |

Sandboxed commands cannot read credential files, the keychain or the 1Password
app, so a command that needs them fails and the agent asks to retry it outside
the sandbox. Approved commands run without the sandbox's read denies. `op read`,
`op run`, `op inject`, `op item get` and keychain lookups are denied in every
mode: they would put the value in the agent's context or let it run any command
with it. Sandboxes keep exported environment variables and readable workspace
files such as `*.tfvars` or local state; keep secrets out of both.

`op-item-from-secret --vault <vault> --title <title> [--category <category>] [--field <field>] <file>`
stores a `request_secret` file in 1Password. It asks, runs outside the sandbox,
only accepts files under `~/.t3/userdata/secrets`, passes the value to `op` on
stdin, prints only the item's id, title and vault, and deletes the file. Plain
`op item create` with `$(cat <file>)` stays denied: the secret directory is a
Read deny.

## T3 Code permission modes

New threads default to **Auto-accept edits**. Use that mode for Claude;
switch Codex threads to **Auto** by hand in the composer's permission picker.
T3 supports an environment default and project overrides, but no default per
provider or provider instance. Existing threads and project overrides retain
their selected modes; change those separately in T3. See
[T3 permission modes](https://github.com/pingdotgg/t3code/blob/main/docs/user/permission-modes.md)
and the [settings schema](https://github.com/pingdotgg/t3code/blob/main/packages/contracts/src/settings.ts).

| Provider | Auto-accept edits | Auto |
| --- | --- | --- |
| Claude | Sandboxed workspace, scratch and agent-cache writes, configured-remote fetches and `fj` views run without prompts. Nix builds, unlisted network hosts and reads outside allowed paths ask. | Automatic review can approve Nix builds without prompting. Unlisted hosts fail with `CONNECT tunnel failed, response 403` without a prompt. |
| Codex | Observed shell writes ask, including plain `touch`/`rm` in the workspace and `/tmp`, and every agent-cache write. `git fetch origin` and Nix builds also ask. | Workspace and `/tmp` writes run without prompts; automatic review can approve escalations such as Nix builds. |

**Auto** uses provider automatic review; approval requests may still reach you.
**Full access** removes the ordinary approval boundary. T3 injects its own MCP
endpoint and allows its Claude tool namespace; Codex tool-specific prompts
remain separate from shell approvals.

The default Codex, Claude and Pi provider paths and new-thread permission mode
are merged into `~/.t3/userdata/settings.json` during activation. Close T3 before
applying and restart it afterwards. Other instances and app-managed settings
are preserved; declared values are restored on each apply. Custom T3 home
directories are not managed.

Claude uses `~/.local/bin/claude` and Pi uses the sandboxed executable in the
Home Manager profile. Codex uses the Homebrew CLI with the launch argument
`-c 'default_permissions=":workspace"'` to avoid shell startup failures with
custom permission profiles ([T3 #16458](https://github.com/pingdotgg/t3code/issues/16458)).
Terminal Codex keeps its custom profile. No separate launcher or Codex home is
needed.

T3's Codex sandbox differs from the terminal profile
([T3 discussion #6976](https://github.com/pingdotgg/t3code/discussions/6976)).
Do not rely on the terminal profile's secret-file denies in T3. Claude keeps
its own sandbox settings under T3.

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
shell wrappers and uncertain commands ask. Unknown tools and MCP calls also ask.
Nix is different: every command that reaches the daemon socket fails with
`Operation not permitted`, and no approval can grant it. Write and lint Nix
configs, then ask the user to evaluate or build with the
[fixture commands](../../AGENTS.md#validation-commands-no-apply). Only load trusted extensions: they share Pi's process
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
cannot escalate. Explicit secret-file denies remain off-limits; see
[Secrets](#secrets). Do not loop through variants, move credentials or disable
TLS verification.

Nixpkgs-built Go tools use the configured CA bundle; upstream binaries may still
need escalation. Claude adds the Nix bundle to system certificates. Codex adds
it through `NODE_EXTRA_CA_CERTS` and sets `NODE_USE_SYSTEM_CA=0`; an explicit
`--use-system-ca` flag can still trigger sandbox warnings. Private CA overrides
must preserve the required public roots.

To change the policy, edit the [shared policy](../design/agent-permissions.md#one-policy-one-adapter-per-client)
rather than a single client's adapter.
