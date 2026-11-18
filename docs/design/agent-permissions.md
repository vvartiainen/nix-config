# Agent permissions

How the agent clients are restricted and why. Day-to-day behavior is in
[agent permissions](../agents/permissions.md).

## Guidelines

- Keep routine work (inspect, edit, test, commit) inside the sandbox, using
  workspace, scratch and agent-cache paths.
- Review anything beyond that as one specific operation: installs,
  publishing, remote writes, privileged operations and host control. Avoid
  blanket runner approvals and control-socket grants.
- Keep secret-file denies, destructive-command denies and TLS verification;
  never use another tool to evade a denial.
- Shell, file-tool and MCP permissions are separate: host apps and MCP
  servers may act outside the shell sandbox. Skills grant no access.

## One policy, one adapter per client

Shared policy lives in
[permissions.nix](../../nix/modules/home/programs/ai/shared/permissions.nix);
each client module renders it in the client's native format.

The OS sandbox is the boundary. Command rules cannot recognize every spelling,
so they only supplement it; OpenCode has no OS sandbox, so its rules are best
effort. Rex, Kitty and Incus control host services, so they stay out of
socket and network grants. File denies protect known credential paths, not
exported variables or all project content, so any allowed host can receive
readable data.

## Local Git maintenance

Git config and hooks stay read-only to sandboxed commands, because hooks,
aliases, filters and includes would run later in an unsandboxed Git. That
also blocks `branch -d` config cleanup and `git push -u` upstreams.

`agent-git` covers those cases: a fixed grammar running pinned Git in its own
network-free Seatbelt, with no caller-supplied flags, environment or absolute
paths. A misused caller can create, move and remove its own worktrees, delete
merged branches and change upstreams, but cannot install executable config or
publish data. Pi reaches it through a broker bound to the launch repository.
Its worktrees live in `.agent-worktrees`, away from T3's thread paths.

## When friction does not justify a grant

Classify a failure before changing policy: an approved retry that succeeds
proves only that the escape works. Verify a policy change by applying it and
starting a fresh session. T3 Codex's managed sandbox cannot be fixed from the
terminal profile.

| Candidate | Decision |
| --- | --- |
| GitHub hosts | Allow exact `api.github.com` and `raw.githubusercontent.com` only, accepting that readable data can be sent there |
| Normal caches, Git config and hooks | Keep read-only: they can poison or run code in later unsandboxed tools |
| Process inspection | PID-specific queries only: arguments can reveal tokens |
| SSH agent and keys | Keep current boundaries: a signing failure is not a reason for more access |
| T3 settings files | Keep denied: they can hold literal provider environment values |

Broad store searches and SQLite contention need narrower or serialized
commands, not grants. Remote writes and host-daemon builds stay reviewed,
apart from Pi's bounded forge flow.
