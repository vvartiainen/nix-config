# Agent permissions

How the agent clients are restricted and why. Day-to-day behavior, sandbox
paths and diagnostics are in [agent permissions](../agents/permissions.md).

## Guidelines

- Keep routine development low friction: inspect, edit, test and commit inside
  the sandbox using workspace, scratch and agent-cache paths.
- Review additional access as a specific full-access operation. Keep sandboxing
  enabled; avoid blanket runner approvals and control-socket grants. Existing
  narrow allowances, such as Claude's read-only `gh` commands, still apply.
- Review installs, publishing, remote writes, privileged operations and host
  control, apart from a narrow sandbox-bounded routine flow such as Pi's branch
  push and pull-request body. Keep secret-file restrictions, destructive-command
  denies and TLS verification; do not use another tool to evade a denial.
- Treat shell, file-tool and MCP permissions separately: host apps and servers
  may act outside the shell sandbox. Skills and available tools grant no access.

## One policy, one adapter per client

Shared policy lives in [permissions.nix](../../nix/modules/home/programs/ai/shared/permissions.nix);
each client module renders its own adapter in the client's native format.

The OS sandbox is the boundary. Command rules cannot recognize every spelling
or operation hidden in a script, so they only supplement the sandbox; where a
client has no OS sandbox, as with OpenCode, its rules are best effort.

Rex, Kitty and Incus delegate to host services, so their control endpoints
stay out of sandbox socket and network grants and each use is reviewed
instead.

Filesystem denies protect known credential paths, not all sensitive project
content or exported variables, so any allowed host can receive readable data.

## Local Git maintenance

Git config and hooks stay read-only to sandboxed commands: hooks, fsmonitor,
aliases, filters and includes would let them persist command execution for a
later user-run Git. No narrower grant fixes the routine cases. Writing only
refs, logs and `.git/worktrees` cannot remove branch config after
`branch -d`, writable per-worktree config has the same execution risk, and
`git push -u` needs the same config write for its upstream.

`agent-git` covers those cases instead. It accepts a small fixed grammar and
runs pinned Git in its own network-free Seatbelt. Config is writable only
during fixed branch operations, which run no checkout filters, and worktree
operations protect common config even from filters that re-exec Git. The
caller cannot pass Git flags, an executable, environment, a sandbox profile or
absolute destinations. A prompt-injected caller can create local worktrees,
remove clean helper-managed ones, delete merged branches and change upstreams,
but cannot install executable config or publish data.

Claude and terminal Codex grant only the helper entry point, not unrestricted
Git. Pi cannot escape Safehouse, so its unsandboxed launcher runs a
short-lived broker bound to the launch repository, reached through one extra
socket with the same grammar. Managed worktrees live in `.agent-worktrees` to
stay clear of T3's live thread paths.

## When friction does not justify a grant

Classify the failure before changing shared policy. An approved command that
succeeds proves only that the escape works, not that the sandbox caused the
failure. Generated settings establish intent, not live behavior: apply
manually and start fresh sessions to verify a changed policy. T3 Codex's
managed sandbox cannot be repaired by extending the terminal profile.

| Candidate | Prompt-injection capability and exfiltration risk | Decision |
| --- | --- | --- |
| GitHub API/raw shell hosts | An agent could request arbitrary paths, retrieve attacker code, or send readable workspace data in URLs to the service and its logs. API access also permits writes to an attacker's repository if usable credentials are available; raw content is not a repository boundary. | Exact API/raw hosts are allowed for routine downloads, without GitHub wildcards; other hosts remain reviewed in Claude. This accepts uploads of readable data to allowed hosts. Web-tool access is separate; these grants cannot fix T3 Codex. |
| Additional cache or shared Git writes | Writable normal caches can poison later unsandboxed tools; writable Git config/hooks can execute code on a later host-side Git command and send data using that command's access. | Keep disposable agent caches and protected Git metadata. A T3 cache failure or a directly reviewed commit does not establish a missing shared grant. |
| Process inspection outside the sandbox | Process arguments can reveal tokens and private paths. A shell pipeline filters only after collection; captured data can leave through an already-allowed network endpoint or remote write. | Review a PID-specific query without arguments when needed; no broad `ps` escape or wrapper. |
| SSH agent/key access | Agent signing can authenticate beyond one repository; readable keys could be copied to an external endpoint. | Keep existing client boundaries. An SSH signing failure is not evidence for more socket, keychain or credential access. |

Broad store searches and SQLite contention need narrower commands or serialized
inspection, not filesystem grants. Remote writes and host-daemon builds remain
reviewed, apart from Pi's bounded forge flow.

Raw T3 settings are not a credential-free inspection interface: upstream's
[provider instance schema](https://github.com/pingdotgg/t3code/blob/main/packages/contracts/src/providerInstance.ts)
permits literal environment values and arbitrary provider configuration, and
only recognized credential fields use a secret store. Keep both settings files
denied; inspect the declared module instead.
