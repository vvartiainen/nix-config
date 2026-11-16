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

The shared shell network allowlist permits the exact GitHub API and raw-content
hosts for routine source inspection and artifact downloads. This accepts that
readable workspace data can be sent to those hosts, including API uploads with
an attacker-supplied token. Filesystem denies protect known credential paths,
not all sensitive project content or exported variables. This tradeoff reduces
download prompts without granting GitHub wildcards or local control endpoints;
the [operating guide](../agents/permissions.md#working-in-the-sandboxes) lists
the boundaries. Terminal Codex and Pi already permit ordinary internet access;
T3 Codex retains its own managed policy.

## Local Git maintenance

Direct Git config writes stay blocked: hooks, fsmonitor, aliases, filters and
includes can persist command execution for a later user invocation. Granting
only refs/logs/packed-refs and `.git/worktrees` cannot remove stale branch
config after `branch -d`. Writable per-worktree config has the same execution
risk and does not isolate shared branch settings. Pushing without `-u` avoids
new upstream sections but does not clean existing ones.

An upstream section needs the same write, so no narrower grant covers
`git push -u`: the sandbox lets the push through and blocks the config write
that follows it. The fixed branch operations in `agent-git` set an upstream instead,
which keeps the write inside the helper's Seatbelt.

`agent-git` instead validates a small command grammar and runs pinned Git in
its own network-free Seatbelt. Config writes are permitted only during fixed
branch operations, where checkout filters are not run. Worktree operations
protect common config even against filters that directly re-exec Git. The
caller cannot supply Git flags, executable, environment, sandbox profile or
absolute worktree destinations. A prompt-injected caller can create local
worktrees, remove clean helper-managed worktrees, delete merged branches and
change upstreams, but cannot use this entry point to install executable config
or publish data. Git's locks serialize concurrent config changes.

Claude and terminal Codex grant the helper entry point, not unrestricted Git.
Pi cannot escape Safehouse, so its unsandboxed launcher owns a short-lived
broker bound to its launch repository. The sole additional socket accepts the
same fixed argument grammar and runs the same inner Seatbelt. T3 Codex's
per-turn policy remains host-owned and may require approval. Managed worktrees
use a separate `.agent-worktrees` namespace to exclude T3's live thread paths.

## When friction does not justify a grant

Classify the failure before changing shared policy. An approved command that
succeeds proves that escape works; a command run directly with approval
provides no evidence of a sandbox denial. Generated settings establish intent,
not live behavior: apply manually and start fresh sessions to verify a changed
policy. T3 Codex's managed sandbox cannot be repaired by extending the terminal
profile. See [diagnostics](../agents/permissions.md#diagnose-blocked-commands)
for DNS, caches, authentication, concurrency and search-scope failures.

These tempting expansions have costs beyond the immediate task:

| Candidate | Prompt-injection capability and exfiltration risk | Decision |
| --- | --- | --- |
| GitHub API/raw shell hosts | An agent could request arbitrary paths, retrieve attacker code, or send readable workspace data in URLs to the service and its logs. API access also permits writes to an attacker's repository if usable credentials are available; raw content is not a repository boundary. | Exact API/raw hosts are allowed for routine downloads; other hosts remain reviewed in Claude. This accepts uploads of readable data to allowed hosts. Web-tool access is separate; these grants cannot fix T3 Codex. |
| Additional cache or shared Git writes | Writable normal caches can poison later unsandboxed tools; writable Git config/hooks can execute code on a later host-side Git command and send data using that command's access. | Keep disposable agent caches and protected Git metadata. A T3 cache failure or a directly reviewed commit does not establish a missing shared grant. |
| Process inspection outside the sandbox | Process arguments can reveal tokens and private paths. A shell pipeline filters only after collection; captured data can leave through an already-allowed network endpoint or remote write. | Review a PID-specific query without arguments when needed; no broad `ps` escape or wrapper. |
| SSH agent/key access | Agent signing can authenticate beyond one repository; readable keys could be copied to an external endpoint. | Keep existing client boundaries. An SSH signing failure is not evidence for more socket, keychain or credential access. |

Broad store searches and SQLite contention need narrower commands or serialized
inspection, not filesystem grants. Remote writes and host-daemon builds remain
reviewed, apart from Pi's existing bounded forge flow.

Raw T3 settings are not a credential-free inspection interface. Upstream's
[provider instance schema](https://github.com/pingdotgg/t3code/blob/main/packages/contracts/src/providerInstance.ts)
permits literal environment values and arbitrary provider configuration.
[Recognized credential fields](https://github.com/pingdotgg/t3code/blob/main/packages/contracts/src/settingsSecretValue.ts)
use a secret store, but that does not establish safety for every settings field.
Keep both settings files denied; inspect the declared module instead.
