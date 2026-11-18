# Agent permissions and sandboxes

How the sandboxes behave day to day. The reasoning behind the policy is in
[design/agent-permissions](../design/agent-permissions.md); the
[agent comparison](comparison.md) shows what each client runs, asks about and
denies.

The active session's policy is authoritative: apply configuration changes
manually and start fresh sessions. Command rules supplement the OS sandbox;
OpenCode has none, so its rules are best effort. In Copilot, run
`/reset-allowed-tools` to clear old broad grants before testing changed rules.

## Working in the sandboxes

### Files

Terminal sandboxes allow writes in the workspace, `$TMPDIR`, `/tmp` and
`~/.cache/<tool>-agent`. Normal caches and tool installations stay read-only;
install workstation tools manually outside the agent. Tools without their own
cache variable, such as treefmt, uv and pre-commit, use `XDG_CACHE_HOME`
(`~/.cache/xdg-agent`). Under T3 it stays `~/.cache` for Claude and Codex, so
those tools can fail with `Operation not permitted`; in Claude, set the tool's
own cache variable to an agent-cache path.

Go tools that use wasilibs, such as betterleaks from Homebrew or nixpkgs,
cache compiled regex code in `~/Library/Caches/com.github.wasilibs`, which has
no variable to change it. Run them with `env HOME=/tmp/betterleaks-home`.
Inside the sandbox they otherwise crash with `operation not permitted` and a
nil-pointer panic. That directory stays ungranted: unsandboxed runs and Git
hooks execute the cached native code.

T3 Codex uses its own managed writable roots. An inherited cache variable is
not a grant there, and even `NIX_CACHE_HOME=~/.cache/nix-agent` can fail on
`fetcher-locks/*.lock`; use a reviewed retry or a terminal session.

Credentials, shell history, browser profiles, private host data, keys and
environment files are unreadable. Codex and Claude can read sibling projects
next to this checkout; Claude may still ask, so launch with `--add-dir` when a
sibling belongs in the session. T3 Code's caches, attachments, browser
artifacts and worktrees are readable; its settings, database and secrets are
not, because settings can hold literal provider environment values. Inspect
the declared module instead. T3 Codex does not inherit these denies.

Approved unsandboxed commands and host daemons reach beyond all of this;
review them accordingly.

### Network

Terminal Codex and Pi allow ordinary internet access. Claude, Cursor and
Copilot share a package/source host allowlist that also includes the exact
hosts `api.github.com`, `raw.githubusercontent.com`, `pkgs.superlogical.com`
and Rex's tarball redirect host. A host grant covers every path and method, so
sandboxed commands can send readable data to those hosts
([tradeoff](../design/agent-permissions.md#when-friction-does-not-justify-a-grant)).
There are no wildcards; GitHub web, archive and release hosts are unlisted, so
redirects to them need review. T3 Codex uses its own managed policy.

Claude's WebSearch and WebFetch are approved by a `PreToolUse` hook rather than
`WebFetch(domain:…)` rules, because those rules would also open the domains to
sandboxed Bash.

Nix build, run, develop and store operations need review because they delegate
to the host daemon; so do recipes that run them, such as `just check` and
`just build`. Unix sockets are blocked except the Nix daemon and
`~/.cache/tofu-agent`, where `PLUGIN_UNIX_SOCKET_DIR` puts OpenTofu provider
sockets so `tofu validate` runs sandboxed. Symlinks are checked at their
target, so Rex, the SSH agent and 1Password stay blocked. T3 Codex lacks the
OpenTofu grant.

### Git and the forge

Claude and Codex run read-only `gh` and `fj` views without a prompt; SSH,
pushes and forge writes run outside the sandbox after review. Pi has its own
[forge flow](#pi).

These rules match standalone commands only. With `cd`, pipes, loops, `-C` or
`-H` the command runs sandboxed and fails (`fj` reports `Operation not
permitted` from its keychain) or prompts.

- Claude excludes standalone `git push` from the sandbox: it asks once, then
  runs outside it. Force forms are denied. `allowed_domains` does not help a
  sandboxed push: it applies only in auto mode and provides no SSH agent.
- Claude runs standalone `git fetch` from a configured remote without a prompt
  ([fetch hook](#claudes-fetch-hook)); Codex asks for every fetch.
- `fj pr edit <n> body` and `fj issue edit <n> body` take the body only as an
  argument; use `fj-edit-body pr|issue <n> <file>` instead of `$(cat ...)`.
  `fj pr create`, `fj pr comment`, `fj issue create` and `fj issue comment`
  take `--body-file`.
- Local `git rebase`, `reset` and `clean` run sandboxed; their destructive
  forms are denied.
- Git config and hooks are read-only, including `config.worktree` and settings
  under `.git/worktrees/`, because they could run commands during a later
  unsandboxed Git invocation. `git push -u` therefore pushes but cannot record
  the upstream. Create branches with
  `git switch --no-track -c <branch> origin/main` and use
  [`agent-git`](#local-git-maintenance) when an upstream is needed.

#### Claude's fetch hook

A `PreToolUse` hook reads `git remote` in the command's directory and lets a
standalone `git fetch` through when it uses only known option flags and names
configured remotes (with refspecs), `--all`, or `--multiple`/`--prefetch` with
configured remotes. Everything else asks: explicit URLs, scp-style addresses,
paths, unknown remotes or options, `--upload-pack`/`-u`, tilde syntax,
noncanonical whitespace, unclassified shell syntax and remote-read failures.

- Configured remotes are trusted as configured, including file URLs,
  `insteadOf` rewrites and `ext::` transports.
- The hook uses
  [`onFailure: "block"`](https://code.claude.com/docs/en/hooks#block-the-action-when-a-hook-fails),
  which needs Claude Code 2.1.295 or later: if it crashes, cannot start or
  times out, every Bash call is blocked.
- It keeps the broad `Bash` matcher because Claude's
  [`if` filter](https://code.claude.com/docs/en/hooks#common-fields) cannot
  reliably match every wrapped, quoted or compound fetch spelling. The fetch
  ask patterns stay as defence in depth; a hook's `ask` prompts even when an
  allow rule matches.

### Local Git maintenance

Run the installed `agent-git` helper standalone, from the repository or one of
its linked worktrees:

```sh
agent-git worktree add topic origin/main
agent-git worktree move topic renamed
agent-git worktree remove renamed
agent-git branch -d agent/topic
agent-git branch -m feature/old feature/new
agent-git branch --set-upstream-to origin/main feature/topic
agent-git branch --unset-upstream feature/topic
```

- `add` creates branch `agent/<name>` without an upstream in the main
  checkout's `.agent-worktrees/<name>`. `move` and `remove` accept only names
  there; removal keeps Git's dirty and locked checks.
- `branch -d` also removes the branch's config section and refuses a branch
  checked out elsewhere. `-m` updates linked worktree HEADs and never
  overwrites a branch. Upstream changes accept plain branch names only.
- Other operations and arbitrary config changes are rejected. Checkouts that
  need external filters, such as Git LFS, need reviewed raw Git.

Claude and terminal Codex run the helper outside their sandbox without a
prompt; it runs pinned Git in its own restricted sandbox
([why](../design/agent-permissions.md#local-git-maintenance)). Pi reaches it
through a session broker. T3 Codex's per-turn policy may still ask. For normal
commits in linked worktrees, launch terminal Codex through the `codex` zsh
wrapper, which grants the worktree's index and refs.

The helper never moves or removes T3 worktrees under `~/.t3/worktrees`. Do not
remove a worktree that belongs to another live thread, even if its branch is
merged; T3 cleans up its own. Check ownership with
`git worktree list --porcelain` and T3's thread list. Other external worktrees
need reviewed raw Git. Add a sibling repository to the session (`/add-dir` or
`--add-dir`) before working on it.

### Forgejo repository discovery

`fj` takes the repository from an explicit host, the sole remote or the branch
upstream. In worktrees with several remotes and no upstream it cannot infer
one, so keep the allowed subcommand first and name the repository with its
host:

```sh
fj pr search -r '<forge-host>/<owner>/<repo>'
fj issue search -r '<forge-host>/<owner>/<repo>'
fj pr view '<forge-host>/<owner>/<repo>#28'
fj pr status '<forge-host>/<owner>/<repo>#28'
fj issue view '<forge-host>/<owner>/<repo>#1'
fj repo view '<forge-host>/<owner>/<repo>'
```

These forms match the read-only rules in Claude and Codex; writes still ask.
Pi exports `FJ_FALLBACK_HOST`, so the host can be omitted there
(`fj pr view owner/repo#28`).

## Flake update previews

```sh
flake-update-preview
flake-update-preview nixpkgs home-manager
```

The wrapper previews newer pins for the flake files embedded in the applied
configuration, not the working directory: rebuild and apply to preview changed
flake definitions. It accepts plain input names other than `host`, resolves
with the synthetic fixture and writes
`/private/tmp/flake-update-review/flake.lock.new`; that directory must be
yours, mode 0700 and not a symlink. The repository lock stays untouched and
the fixture does not appear in lock diffs. It never builds or applies, but it
fetches inputs into the Nix store outside the sandbox.

Claude and terminal Codex run it outside the sandbox without a prompt; T3
Codex may ask. Cursor and Copilot need an approved retry, and Pi cannot reach
the Nix daemon. Raw `nix flake update` stays reviewed.

## Secrets

Agents never see secret values; the tool that needs a credential fetches it
itself, outside the sandbox. The forge token is the deliberate exception,
restricted so that sandboxed pushes and forge calls need no key.

| Need | How | Review |
| --- | --- | --- |
| `gh`, Git over SSH | The tool uses its keychain token or the SSH agent. Pi reaches the agent socket but no key file | Read-only views run without prompting; writes and pushes ask |
| `fj` and forge HTTPS | Agents get their own token in `~/.local/share/agent-forge`, restricted to selected repositories. Pi's sandbox reads it, so sandboxed `git` and `fj` need no key. Your interactive `fj` login is separate | Pushes and forge writes ask, except Pi's [routine forge flow](#pi); revoke the agent token alone if in doubt |
| Provider or cloud credentials, such as `tofu apply` | Approved retry outside the sandbox; 1Password supplies the credential | The agent's approval prompt, then 1Password's |
| A new value only the user has | T3 `request_secret` file delivery, then `op-item-from-secret` | The user enters it; storing asks |

Sandboxed commands cannot read credential files, the keychain or 1Password,
apart from the forge token. A command that needs them fails, and the agent
asks to retry it outside the sandbox, where the read denies no longer apply.
`op read`, `op run`, `op inject`, `op item get` and keychain lookups are
denied in every mode: they would put the value in the agent's context or let
it run any command with it.

File denies do not hide exported environment variables or readable workspace
files such as `*.tfvars` and local state; keep secrets out of both. Claude and
Codex do not filter credential variables, and Pi relies on Safehouse's
sanitization, so review launch environments separately from file access.

`op-item-from-secret --vault <vault> --title <title> [--category <category>] [--field <field>] <file>`
stores a `request_secret` file in 1Password and deletes it. It asks, accepts
only files under `~/.t3/userdata/secrets`, passes the value on stdin and prints
only the item's id, title and vault. `op item create` with `$(cat <file>)`
stays denied.

## T3 Code permission modes

New threads default to **Auto**, where provider automatic review handles
routine escalations; approval requests may still reach you. Use **Auto-accept
edits** for Claude when sandbox escapes should stay user-reviewed, and switch
Pi threads to **Full access** by hand. T3 has an environment default and
project overrides but no per-provider default; existing threads and project
overrides keep their modes. See
[T3 permission modes](https://github.com/pingdotgg/t3code/blob/main/docs/user/permission-modes.md).

| Provider | Auto-accept edits | Auto |
| --- | --- | --- |
| Claude | Sandboxed workspace, scratch and agent-cache writes, configured-remote fetches and `fj` views run without prompts. Nix builds, unlisted network hosts and reads outside allowed paths ask. | Automatic review can approve Nix builds without prompting. Unlisted hosts fail with `CONNECT tunnel failed, response 403` without a prompt. |
| Codex | Observed shell writes ask, including plain `touch`/`rm` in the workspace and `/tmp`, and every agent-cache write. `git fetch origin` and Nix builds also ask. | Workspace and `/tmp` writes run without prompts; automatic review can approve escalations such as Nix builds. |
| Pi | Every shell command prompts, even `rg` or `git status`, although Pi's own rules allow it. File edits run. | The same: T3 has no automatic review for Pi. |

T3's Pi bridge decides by tool name, not command: only read-only tools pass
without asking, plus file edits under Auto-accept edits, and Pi's allow rules
cannot suppress the prompt. Under **Full access** T3 raises no approvals and
Safehouse with Pi's permission extension remains the boundary. Pi's own asks
are then answered inside the session, so a command they cover runs sandboxed
and fails where the sandbox blocks it; Nix stops with `Operation not
permitted`. Lint Nix changes in Pi and validate them in a Claude or Codex
thread. Subagents use their parent thread's mode.

T3 Codex gets a managed per-turn sandbox from T3, so the terminal profile's
network, cache, secret-file and Git metadata grants do not apply, and changing
`network.sandbox` cannot enable its networking
([discussion #6976](https://github.com/pingdotgg/t3code/discussions/6976)).
Claude keeps its own sandbox settings under T3. Sandboxed Pi reaches T3's MCP
endpoint, so its T3 tools work.

## Worktrees

| Client | Managed location or launch requirement |
| --- | --- |
| Codex | `~/.codex/worktrees`, including worktrees created during a session |
| Claude | `<repo>/.claude/worktrees`, with shared Git metadata granted |
| Copilot | `<repo>.worktrees/` |
| Cursor | `~/.cursor/worktrees` and its relocated config's `worktrees` directory |
| OpenCode | Active worktree is part of the selected project |
| Pi | Launch inside the worktree; there is no global managed-worktree grant |

Commits need write access to Git metadata; hooks and config stay protected.
Codex app launches bypass the zsh wrapper: this repository has a persistent
grant, while other repositories may need an explicit metadata-directory grant
and a fresh session. Moving a worktree to `/tmp` does not grant writes to its
original shared Git directory. In T3, attach each thread to its own worktree.

Worktrees separate source edits, not capabilities: clients can read shared
artifacts and some can write managed worktrees or shared refs. Keep secrets
out of readable workspaces and launch environments.

## Pi

Launch `pi` from the project root; launching from home or `/` grants an empty
workspace. Safehouse confines Pi, its extensions, MCP servers and child
commands, and no approval can leave it. Run blocked work manually or in
Claude/Codex, never through Rex or `pi-unsandboxed`.

- **Files**: writes are limited to the project, scratch space, Pi state and
  agent caches. Project `.pi` files, Git hooks and config, a linked worktree's
  `.git` file, permission settings and installed extension code stay
  read-only; Pi's own installed npm package directory stays writable.
- **Forge**: Git and `fj` use the [restricted agent token](#secrets) over
  HTTPS, through a `fj` wrapper and generated Git config that rewrites this
  forge's SSH remotes. `git fetch origin`, branch pushes to `origin` and
  `fj pr create`/`fj pr edit` run without a prompt. Force pushes are denied;
  other remotes, remote deletion or mirroring, direct `main`/`master` pushes,
  merges and issue writes ask. Push without `-u`
  ([why](#git-and-the-forge)). Create or rotate the token with the
  [forge token runbook](../runbooks/forge-token.md).
- **SSH**: `~/.ssh/config`, `known_hosts` and the selected SSH agent socket
  (the declared `SSH_AUTH_SOCK`, otherwise the host app's) are reachable; key
  files are not. The agent can authenticate wherever its keys work, beyond the
  token's repository limits. New host keys cannot be stored from the sandbox,
  so connect once outside Pi first.
- **Nix**: every command that reaches the daemon fails with
  `Operation not permitted`, and no approval can grant it. Write and lint Nix,
  then hand evaluation and builds to the user or a Claude/Codex thread.
- **Network**: internet access without an allowlist. Host-local services and
  sockets are blocked except system DNS, the host app's tool endpoint
  (`T3_MCP_URL`) and the SSH agent, so local dev servers are unreachable. LAN
  hosts stay reachable, and an unassigned loopback-looking address can route
  off-host, so this is not a private-network boundary.
- **Commands**: the pinned permission extension (`/permission-system show`)
  allows file tools, bash, tool discovery, web research and the forge flow
  above. Installs, publishing, credentials, host control, shell wrappers,
  unknown tools, other MCP calls and uncertain commands ask. T3's own tools
  follow the thread's mode.
- **Extensions**: load only trusted ones; they share Pi's process access,
  including its stored login. Prefer a provider key passed in the environment.

Web search returns raw results without browser launches or cookie extraction;
`/curator off` closes the optional review UI.

## Terminal and VM control requires review

Rex, Kitty and Incus delegate to host services, so execution, input injection,
terminal capture and VM changes are reviewed. Some clients allow help and
listing calls; Codex asks for every invocation and Claude for every Rex
invocation. Keep their control endpoints out of socket and network grants; if
an approved retry still fails, report it rather than widening access.

## Diagnose blocked commands

| Error | Action |
| --- | --- |
| `Operation not permitted` | Check the path and active grants; use workspace/temp for scratch files. Pi under T3 Full access answers asks inside the session, so Nix daemon work fails here without a prompt |
| `could not write config file …/.git/config` after a push | The upstream write was blocked; this alone does not prove the push succeeded. Confirm with `git ls-remote origin <branch>` and continue without `-u` |
| `curl: (6) Could not resolve host` | May be DNS or sandbox network policy; success of the exact approved retry supports the latter, not a new host grant |
| Nix `fetcher-locks/*.lock` denied | Check active writable roots, especially T3 Codex; inherited `NIX_CACHE_HOME` is not a grant |
| Ignored SQLite eval-cache busy warning | Avoid concurrent evaluated-option probes; serialize if results are affected, without changing permissions |
| SSH `sign_and_send_pubkey` / `communication with agent failed`, then `Too many authentication failures` | Authentication failure; one exact reviewed retry may resolve a transient failure. Persistent failure needs user diagnosis outside the agent; do not open credential paths |
| `rg --files /nix/store` hits a transient directory | Narrow the search to the known derivation output or artifact glob; do not grant more store access |
| `403`, `Forbidden`, `CONNECT tunnel failed`, or host not allowlisted | Check whether sandbox policy blocked the host; request scoped approval if needed |
| Go `x509: OSStatus -26276` | macOS trust-service access may be blocked; request an approved retry. Nixpkgs-built Go tools use the configured CA bundle; private CA overrides must keep the public roots |
| Node OpenSSL configuration read failure | Codex grants `/System/Library/OpenSSL`; apply and restart if the grant is missing |
| `device not configured` on `/dev/tty` | Use non-interactive flags |

Retry a confirmed sandbox failure once with escalation where supported; Pi
cannot escalate. Explicit secret-file denies remain off-limits. Do not loop
through variants, move credentials or disable TLS verification.

For a stalled push, prefer the command session's status and output. If process
inspection is needed, review a query for known process IDs, such as
`ps -p <pid> -o pid=,ppid=,etime=,stat=,comm=`. Avoid full argument dumps such
as `ps -axo ...command | rg ...`: they read every process's arguments before
filtering and can expose tokens or private paths.

To change the policy, edit the
[shared policy](../design/agent-permissions.md#one-policy-one-adapter-per-client)
rather than a single client's adapter.
