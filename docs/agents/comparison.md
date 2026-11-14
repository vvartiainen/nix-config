# Agent comparison

What each agent client may do under the [shared policy](../design/agent-permissions.md#one-policy-one-adapter-per-client)
and which one to pick. Paths, secrets, worktrees and diagnostics are in
[agent permissions](permissions.md).

In the tables, **runs** means without a prompt, **asks** means you approve
each use, and **denied** means no approval can allow it.

## Which agent to use

| Task | Use | Why |
| --- | --- | --- |
| Everyday work in this or another repository: edit, test, evaluate Nix, commit, read pull requests, web research | Claude Code, in the terminal or T3 | Sandboxed, reaches the Nix daemon, reads `gh`/`fj`, [configured-remote fetches](permissions.md#working-in-the-sandboxes) and web research without prompts |
| The same, with downloads from arbitrary hosts | Codex in the terminal | Sandboxed with ordinary internet access |
| T3 work that needs a Codex model | Codex in T3 | Use the [T3 permission mode guidance](permissions.md#t3-code-permission-modes) |
| Code you do not trust, or an untrusted extension or MCP server | Pi | The whole process is confined and no approval can leave the sandbox |
| Nix builds, pushes, forge writes, `tofu apply`, local dev servers | Claude Code or Codex | They can run one approved command outside the sandbox; Pi cannot |
| Cursor or Copilot models | Cursor, Copilot | Sandboxed like Claude, but `gh`, `fj` and fetches need an approved retry |
| OpenCode models | OpenCode, on trusted repositories only | No OS sandbox: its command rules are the only boundary, so read each prompt |

## Boundary

| | Claude Code | Codex | Cursor | Copilot | OpenCode | Pi |
| --- | --- | --- | --- | --- | --- | --- |
| OS sandbox | Each Bash command | Each command | Each command | Each command and hook (experimental) | None | Whole process, with extensions and MCP servers |
| Outside the sandbox | File tools, MCP servers, `gh`, `fj`, `git fetch`, Rex | File tools, MCP servers, allowed `gh`/`fj` views | File tools, MCP servers | File tools, MCP servers | Everything | Nothing |
| Mode | Accept edits | On request, reviewed by you | Allowlist, with a shell hook | Allow and deny flags from the `copilot` shell function | Ordered rules, last match wins | Permission extension, YOLO off |
| Approved run outside the sandbox | Yes | Yes | Yes | Yes | Not applicable | Never |
| Start it | `claude` | `codex`, through the zsh wrapper in linked worktrees | `cursor-agent` | `copilot` from zsh; other shells skip the flags | `opencode` | `pi` from the project root |

## Files

| | Claude Code | Codex | Cursor | Copilot | OpenCode | Pi |
| --- | --- | --- | --- | --- | --- | --- |
| Workspace writes | Runs | Runs | Runs | Runs | Runs | Runs |
| Writes elsewhere | Scratch and agent caches; rest asks | Scratch, agent caches, its worktrees; rest asks | Scratch, agent caches, its worktrees; rest asks | Scratch and agent caches; rest asks | File tools ask; shell is not confined | Scratch, agent caches, Pi state; rest fails |
| Reads outside the workspace | Sibling projects, tool paths and system paths; rest of home asks | Sibling projects and tool paths; rest of the disk asks | Tool paths; rest asks | Tool paths; rest asks | File tools ask; shell is not confined | Tool paths; rest fails |
| Credential paths and `.env`, `*.pem`, `*.key` | Denied for commands and the Read tool | Denied | Denied for file tools | Denied | Denied for file tools only | Denied |
| `.git/hooks`, `.git/config` | Read-only | Read-only | Read-only | Read-only | Edit tool denied; shell is not confined | Read-only |

## Network

| | Claude Code | Codex | Cursor | Copilot | OpenCode | Pi |
| --- | --- | --- | --- | --- | --- | --- |
| Commands | Package download hosts; other hosts ask | Any host | Package download hosts and Cursor's defaults | Package download hosts | Any host | Any host |
| Services on this Mac | Asks | Blocked | Client default | Blocked | Reachable | Blocked |
| Unix sockets | Nix daemon and the OpenTofu plugin directory | Nix daemon and the OpenTofu plugin directory | Client default | Nix daemon, OpenTofu plugin directory and Herdr | Any | None, so no Nix |
| Web tools | Search and fetch run | Live web search | Documentation domains run | Documentation domains run | Client default | Search and fetch run |

## Commands

| | Claude Code | Codex | Cursor | Copilot | OpenCode | Pi |
| --- | --- | --- | --- | --- | --- | --- |
| Inspection: `git status`, `git diff`, `ls`, `cat` | Runs | Runs | Runs | Runs | Runs, unsandboxed | Runs |
| `nix eval`, `nix flake show` | Runs | Runs | Runs if Cursor's sandbox reaches the daemon | Runs | Runs, unsandboxed | Fails |
| Tests, builds, `git add`, `git commit`, `rm`, `just` | Runs | Runs | Runs; pipes, variables and redirects ask | Listed runners and `just lint` run; the rest asks | Asks | Runs |
| Nix build, run, develop and store | Asks | Asks | Asks | Asks | Asks | Fails |
| Installs, publishing, `sudo`, `ssh`, `open`, `tofu apply` | Asks | Asks | Asks | Asks | Asks | Asks; fails where it needs a host service |
| `git push`, forge writes | Asks | Asks | Asks | Asks | Asks | Asks; SSH and tokens fail |
| [Flake update preview](permissions.md#flake-update-previews) | Runs outside sandbox | Runs outside sandbox (T3 may ask) | Approved retry | Approved retry | Runs, unsandboxed | Fails |
| [`git fetch` from a configured remote](permissions.md#working-in-the-sandboxes) | Runs | Asks | Asks | Asks | Asks | Asks; SSH fails |
| `gh` and `fj` read-only views | Runs | Runs | Approved retry | Approved retry | Runs | Fails without a token |
| Rex, Kitty, Incus | Rex always asks; others ask beyond help and listings | Always asks | Asks beyond help and listings | Asks beyond help and listings | Asks beyond help and listings | Asks, then fails |
| `op read`, keychain lookups, force push, `git reset --hard`, `git clean -f`, disk erase | Denied | Denied, exact prefixes only | Denied | Denied, exact prefixes only | Denied | Denied |
| Catalog MCP tools | Runs | Client prompt | Runs | Runs | Client default | Asks |

Where a client matches exact prefixes only, a reordered form such as
`git reset HEAD~1 --hard` is not denied: it runs in the sandbox or asks.

## In T3 Code

Managed providers receive the same agent cache path through T3's
[provider environment](permissions.md#working-in-the-sandboxes).

The tables above describe terminal clients. Choose the provider's mode using
[T3 Code permission modes](permissions.md#t3-code-permission-modes),
which covers the new-thread default, manual overrides and observed behavior.


| Provider | Difference from the terminal |
| --- | --- |
| Claude | Same sandbox settings. Code Mode is off and T3's own tools run |
| Codex | Sandbox differs from the terminal profile; see the mode guidance above |
| Pi | Same Safehouse sandbox, so T3's local tools are unreachable |
| OpenCode | Same rules, no OS sandbox |

## Using them

- Apply a policy change with `just switch`, with the agent clients closed,
  then start new sessions. Running sessions keep their old policy.
- Approve an escape for one specific command. Read what it runs outside the
  sandbox: approved commands lose the credential denies.
- Give agents secrets only through the [secret flow](permissions.md#secrets).
- When a command fails in the sandbox, follow
  [diagnose blocked commands](permissions.md#diagnose-blocked-commands).
