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
  control. Keep secret-file restrictions, destructive-command denies and TLS
  verification; do not use another tool to evade a denial.
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
