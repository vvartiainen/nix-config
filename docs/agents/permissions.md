# Agent permissions and sandboxes

Day-to-day sandbox behavior. What each client may do is in the
[agent comparison](comparison.md); the reasoning is in
[design/agent-permissions](../design/agent-permissions.md).

Running sessions keep the policy they started with: apply configuration
changes manually and start fresh sessions. In Copilot, run
`/reset-allowed-tools` before testing changed rules.

## Working in the sandboxes

### Files

- Writable: the workspace, `$TMPDIR`, `/tmp` and `~/.cache/<tool>-agent`.
  Normal caches and tool installs are read-only; install tools manually.
- Tools without their own cache variable (treefmt, uv, pre-commit) use
  `XDG_CACHE_HOME=~/.cache/xdg-agent`. Under T3, Claude and Codex keep
  `~/.cache`, so set the tool's own cache variable to an agent-cache path.
- T3 Codex uses its own managed writable roots: inherited cache variables are
  not grants there, and Nix `fetcher-locks/*.lock` can fail. Use a reviewed
  retry or a terminal session.
- Unreadable: credentials, shell history, browser profiles, private host data,
  keys, environment files and T3's settings, database and secrets. Inspect
  the declared T3 module instead.
- Claude and Codex read sibling projects; add one to a Claude session with
  `/add-dir` or `--add-dir` before working on it.
- Run `agent-betterleaks` with the usual `betterleaks` arguments: plain
  `betterleaks` crashes in the sandbox on its regex cache under
  `~/Library/Caches`.

Approved unsandboxed commands and host daemons reach beyond all of this.

### Network

- Terminal Codex and Pi: ordinary internet access. T3 Codex: its managed
  policy.
- Claude, Cursor and Copilot: a shared package/source host list plus
  `api.github.com`, `raw.githubusercontent.com`, `pkgs.superlogical.com` and
  Rex's tarball host. No wildcards; GitHub web, archive and release hosts need
  review. A listed host accepts any request, so keep secrets out of readable
  files and the environment.
- Nix build, run, develop and store commands ask, because they use the host
  daemon; so do recipes such as `just check` and `just build`.
- Unix sockets are blocked except the Nix daemon and `~/.cache/tofu-agent`
  (OpenTofu provider sockets, so `tofu validate` runs sandboxed).

### Git and the forge

Run `gh`, `fj`, `git fetch` and `git push` as standalone commands, without
`cd`, pipes, loops, `-C` or `-H`; otherwise they run sandboxed and fail or
prompt.

- Read-only `gh` and `fj` views run without a prompt in Claude and Codex;
  forge writes ask.
- `git push` asks once in Claude, then runs outside the sandbox. Force pushes
  are denied. Do not retry a push with `allowed_domains`.
- Claude runs `git fetch` from configured remotes without a prompt
  ([fetch hook](#claudes-fetch-hook)); Codex asks.
- Set bodies from files: `fj-edit-body pr|issue <n> <file>`, or
  `--body-file` on `fj pr create`, `fj pr comment`, `fj issue create` and
  `fj issue comment`.
- Destructive `git rebase`, `reset` and `clean` forms are denied.
- Git config and hooks are read-only, so `git push -u` cannot record the
  upstream. Create branches with `git switch --no-track -c <branch> origin/main`
  and set upstreams with [`agent-git`](#local-git-maintenance).

#### Claude's fetch hook

A `PreToolUse` hook allows a standalone `git fetch` that names only configured
remotes (with refspecs), `--all` or `--multiple`, with known option flags.
URLs, paths, unknown remotes or options and `--upload-pack` ask. Configured
remotes are trusted as configured. If the hook crashes or times out, every
Bash call is blocked.

### Local Git maintenance

Run `agent-git` standalone from the repository or a linked worktree:

```sh
agent-git worktree add topic origin/main   # branch agent/topic in .agent-worktrees/topic
agent-git worktree move topic renamed
agent-git worktree remove renamed
agent-git branch -d agent/topic
agent-git branch -m feature/old feature/new
agent-git branch --set-upstream-to origin/main feature/topic
agent-git branch --unset-upstream feature/topic
```

- `move` and `remove` accept only names under the main checkout's
  `.agent-worktrees`; other operations are rejected.
- It never touches T3 worktrees under `~/.t3/worktrees`. Do not remove another
  live thread's worktree; T3 cleans up its own.
- Claude and terminal Codex run it without a prompt; T3 Codex may ask; Pi uses
  a session broker. Checkouts needing filters such as Git LFS need reviewed raw
  Git.

### Forgejo repository discovery

With several remotes and no upstream, name the repository with its host:

```sh
fj pr search -r '<forge-host>/<owner>/<repo>'
fj issue search -r '<forge-host>/<owner>/<repo>'
fj pr view '<forge-host>/<owner>/<repo>#28'
fj pr status '<forge-host>/<owner>/<repo>#28'
fj issue view '<forge-host>/<owner>/<repo>#1'
fj repo view '<forge-host>/<owner>/<repo>'
```

These match the read-only rules; writes still ask. In Pi the host can be
omitted (`fj pr view owner/repo#28`).

## Flake update previews

```sh
flake-update-preview                        # all inputs
flake-update-preview nixpkgs home-manager   # selected inputs
```

Previews the flake embedded in the applied configuration, not the working
directory, and writes `/private/tmp/flake-update-review/flake.lock.new`. The
repository lock stays untouched. Claude and terminal Codex run it without a
prompt; T3 Codex may ask; Cursor and Copilot need an approved retry; Pi cannot.
Raw `nix flake update` stays reviewed.

## Secrets

Agents never see secret values; the tool that needs a credential fetches it
outside the sandbox.

| Need | How |
| --- | --- |
| `gh`, Git over SSH | Keychain token or SSH agent; writes and pushes ask |
| `fj` and forge HTTPS | Agent token in `~/.local/share/agent-forge`, limited to selected repositories ([runbook](../runbooks/forge-token.md)) |
| Provider or cloud credentials, such as `tofu apply` | Approved retry outside the sandbox; 1Password supplies the credential |
| A new value only the user has | T3 `request_secret` file delivery, then `op-item-from-secret` |

```sh
op-item-from-secret --vault <vault> --title <title> [--category <category>] [--field <field>] <file>
```

It stores a `request_secret` file from `~/.t3/userdata/secrets` in 1Password
and deletes it. `op read`, `op run`, `op inject`, `op item get`, keychain
lookups and `op item create` with `$(cat ...)` are denied. File denies do not
hide exported variables or readable files such as `*.tfvars`.

## T3 Code permission modes

| Provider | Mode | Behavior |
| --- | --- | --- |
| Claude | Auto (default) | Automatic review can approve Nix builds; unlisted hosts fail with `403` |
| Claude | Auto-accept edits | Use when sandbox escapes should stay user-reviewed |
| Codex | Auto | Workspace and `/tmp` writes run; automatic review approves escalations |
| Pi | Full access | Set by hand; otherwise every shell command prompts |

Existing threads and project overrides keep their modes; subagents use their
parent's mode. T3 Codex gets a managed per-turn sandbox, so the terminal
profile's network, cache and Git metadata grants do not apply. Under Full
access, Pi's Nix commands fail with `Operation not permitted`: lint Nix in Pi
and validate it in a Claude or Codex thread. See
[T3 permission modes](https://github.com/pingdotgg/t3code/blob/main/docs/user/permission-modes.md).

## Worktrees

| Client | Managed worktrees |
| --- | --- |
| Codex | `~/.codex/worktrees` |
| Claude | `<repo>/.claude/worktrees` |
| Copilot | `<repo>.worktrees/` |
| Cursor | `~/.cursor/worktrees` |
| Pi | Launch inside the worktree |

Commits need Git metadata writes; hooks and config stay protected. Codex app
launches bypass the zsh wrapper, so other repositories may need an explicit
metadata grant. In T3, attach each thread to its own worktree.

## Pi

Launch `pi` from the project root. Safehouse confines Pi, its extensions, MCP
servers and child commands, and no approval can leave it; run blocked work
manually or in Claude/Codex, never through Rex or `pi-unsandboxed`.

- **Files**: writes only to the project, scratch, Pi state and agent caches.
- **Forge**: Git and `fj` use the [agent token](#secrets) over HTTPS.
  `git fetch origin`, branch pushes to `origin` and `fj pr create`/`edit` run
  without a prompt; merges, issue writes, other remotes and `main` pushes ask.
  Push without `-u`.
- **SSH**: the SSH agent socket is reachable, key files are not. Connect to a
  new host once outside Pi to store its host key.
- **Nix**: commands that reach the daemon fail; hand evaluation and builds to
  the user or a Claude/Codex thread.
- **Network**: internet without an allowlist; local services are blocked
  except DNS, `T3_MCP_URL` and the SSH agent. LAN hosts stay reachable.
- **Commands**: `/permission-system show` lists the rules. Installs,
  publishing, credentials, host control and unknown tools ask.
- **Extensions**: load only trusted ones; they share Pi's login.

## Terminal and VM control

Rex, Kitty and Incus control host services, so their use is reviewed. If an
approved retry still fails, report it instead of widening access.

## Diagnose blocked commands

| Error | Action |
| --- | --- |
| `Operation not permitted` | Check the path and grants; use workspace or temp paths |
| `could not write config file …/.git/config` after a push | Only the upstream write failed; confirm with `git ls-remote origin <branch>` |
| `403`, `Forbidden`, `CONNECT tunnel failed` | Host not allowlisted; ask for a scoped approval |
| `curl: (6) Could not resolve host` | DNS or sandbox network policy |
| Nix `fetcher-locks/*.lock` denied | Check writable roots, especially in T3 Codex |
| SSH `communication with agent failed` | Retry once; persistent failures are for the user to diagnose |
| Go `x509: OSStatus -26276` | macOS trust service blocked; ask for an approved retry |
| `device not configured` on `/dev/tty` | Use non-interactive flags |

Retry a confirmed sandbox failure once with escalation; Pi cannot escalate.
Do not loop through variants, move credentials or disable TLS verification.
Inspect stalled processes by PID (`ps -p <pid> -o pid=,etime=,stat=,comm=`),
not with full argument dumps, which can expose tokens.

To change the policy, edit the
[shared policy](../design/agent-permissions.md#one-policy-one-adapter-per-client).
