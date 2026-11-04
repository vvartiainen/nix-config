# Agent permissions and sandboxes

The OS sandbox limits routine commands; approval allows reviewed actions beyond
it. Active session policy is authoritative. Skills and MCP availability do not
grant filesystem or command access.

## Client behavior

| CLI | Routine commands | Approval boundary |
| --- | --- | --- |
| Codex | Run inside the configured sandbox | Ask rules and sandbox escapes |
| Claude Code | Run inside the configured sandbox | Ask rules, escapes and unlisted hosts; `gh` runs outside it |
| Cursor | Run in sandbox | Escapes; Rex has no per-command ask rule here |
| Copilot | Shared safe-command allowlist | Unlisted commands, file edits and sandbox bypasses |
| OpenCode | No OS sandbox | Commands outside its allowlist ask |
| Pi | No configured permission boundary | Runs with the user's normal access |

Keep sandboxing enabled. Persistent broad command approvals can weaken these
defaults. In Copilot, use `/reset-allowed-tools` to clear old broad grants before
testing changed rules. Start fresh sessions after permission changes.

## Working in the sandboxes

- Write in the workspace, `$TMPDIR`, `/tmp`, or `~/.cache/<tool>-agent`.
  Package cache variables already point there; do not redirect them.
- Package download hosts are allowlisted. Other hosts need approval or a
  sandbox bypass; exact behavior differs by client and mode.
- Git status, diff, add and commit work. Hooks and Git config are protected
  where supported to keep them from becoming an escape route.
- Normal caches and tool installations stay read-only. Install tools manually
  outside the agent session; use non-interactive commands for agent checks.
- Credential files, shell history, browser profiles, private host data, keys
  and environment files are restricted. Do not work around a denied read.

Codex and Claude run `just`, `npm run`, `npx`, `npm test`, `cargo test` and
`terraform validate` sandboxed without prompts. Copilot requires normal approval
for unlisted commands. `nix build` and `nix fmt` require approval in Codex and
Claude because they delegate work to the Nix daemon outside the agent sandbox.
Prefix rules do not inspect commands inside wrappers or scripts.

For nix-config, follow [AGENTS.md](../AGENTS.md): validate against the public
fixture, never read private host data for routine checks, and never apply the
fixture system. The user validates and applies real host configuration manually.

## Rex control requires review

Rex can execute through a separately running server with the server account's
permissions. An approved call can therefore leave the calling agent's sandbox.
Codex and Claude prompt for Rex calls, including help and guide commands;
Copilot leaves them unlisted. Keep Rex endpoints out of sandbox socket/network
allowlists and avoid persistent broad approvals. Cursor and Pi do not have the
same Rex prompt coverage. The GUI Remote Control toggle alone does not constrain
all server commands.

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
roots. Certificate and per-client details are in Backlog doc-3.

Shared policy is in [permissions.nix](../nix/modules/home/programs/ai/permissions.nix);
each CLI module renders its own adapter. Detailed policy tables, Codex profiles,
cache variables, certificate rationale and known limits:
Backlog **doc-3 — AI CLI permissions and sandbox behavior**.
