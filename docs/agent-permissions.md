# Agent CLI permissions

Command rules, fetch domains, and sandbox paths are defined once in
`nix/modules/home/programs/ai/permissions.nix` and rendered into each CLI's
native format. Each CLI module adds its own sandbox and approval settings.

The model follows Codex: **the sandbox is the boundary, and prompts are for
leaving it.** Routine commands and workspace edits run without approval inside
an OS sandbox. Prompts are reserved for commands that need extra review and
for anything that has to run outside the sandbox.

## Approval behavior

| CLI | Sandboxed commands | File edits | Still prompts |
|---|---|---|---|
| Codex | Run without approval (`on-request`) | Auto-applied in the workspace | Ask rules, sandbox escapes |
| Claude | Run without approval (`autoAllowBashIfSandboxed`) | Auto-accepted in the workspace (`acceptEdits`) | Ask rules, sandbox escapes |
| Cursor | Run without approval (`Run in Sandbox`) | CLI default | Sandbox escapes |
| Copilot | Prompted unless allowlisted | Prompted | Everything not allowlisted |
| OpenCode | No sandbox; `*` is ask | CLI default | Everything not allowlisted |
| Pi | No permission config | — | — |

Copilot stays on manual approval. It has no "approve if sandboxed" setting,
only a blanket `--allow-tool shell`, and its default sandbox grants the user
profile and open outbound network, with a per-command bypass. OpenCode has no
OS sandbox, so its rules are the only boundary.

## Shared rules

| List | Purpose |
|---|---|
| `allowedCommands` | Read-only prefixes (`git status`, `nix eval`, `gh pr view`, …) allowed everywhere, including outside a sandbox |
| `exactCommands` | Allowed only as written (`git branch --show-current`); not available in Codex, which only has prefix rules |
| `askCommands` | Run project-controlled code or build via the Nix daemon (`just`, `npm run`, `nix build`, …); always prompt, even when sandboxed |
| `deniedCommands` | Never auto-approved (`op`, `security`, `gh auth`, `sudo`, `just switch`, …) |
| `homeSecretPaths`, `secretFilePatterns` | Credential files denied for reads (`~/.ssh`, `~/.aws`, `*.pem`, …), plus `.env` files |
| `fetchDomains` | Docs and registry sites the web-fetch tools may read |
| `sandboxNetworkDomains` | Package download hosts sandboxed commands may reach; upload-capable registries are excluded |
| `sandboxReadonlyPaths` | Tool paths outside the sandboxes' built-in grants (`/nix/store`, mise, Homebrew, git config) |

Prefix denies are not a hard boundary: `sh -c '…'` or an absolute path does
not match them. With sandboxed commands auto-approved, those forms now run
without a prompt, but only inside the sandbox.

## Sandbox boundaries

| | Codex | Claude |
|---|---|---|
| Reads | Denied outside the workspace, except tool paths and Codex's runtime set | Allowed everywhere except credential paths and `.env` files |
| Writes | Workspace, `~/.cache/nix-agent`, `~/.cache/cargo-agent` | Working directory, `$TMPDIR`, `~/.cache/nix-agent` |
| Read-only in the workspace | `.git/hooks`, `.git/config` | `.git/hooks`, `.git/config` |
| Network | `sandboxNetworkDomains` through the Codex proxy; other hosts ask for approval | `sandboxNetworkDomains` plus WebFetch-allowed domains |
| Unix sockets | Nix daemon only | Nix daemon only |

Git runs hooks and config outside the sandbox, so both are read-only to
prevent an escape. Sandboxed Nix uses `~/.cache/nix-agent` instead of the
normal Nix cache, and builds run unprivileged through the daemon.

Claude's sandbox can read most of the disk; the network allowlist limits where
that data could go. Matching Codex would mean denying reads under `~` and
allowing back what tools need.

## Edits through scripts

Agents sometimes edit files with Python or `sed` instead of the edit tool.
Inside the sandbox these are limited to the same write paths, and in Claude
they no longer prompt. They bypass edit-tool features, though: `Edit(…)`
permission rules, `/rewind` checkpoints, `Edit|Write` hooks, diff review, and
the stale-file and unique-match checks. Auto-accepting edit-tool edits keeps
agents from preferring scripts just to avoid prompts.

## Changing the setup

- Shared lists: `nix/modules/home/programs/ai/permissions.nix`
- Claude sandbox and mode: `claude-code.nix`
- Codex profile, proxy, and git worktree grants: `permissions.nix`
  (`codexPermissions`) and `codex.nix`
- Copilot sandbox and tool flags: `github-copilot-cli.nix`
- Cursor sandbox mode: `cursor-cli.nix`

Copilot reads tool rules only from CLI flags, so a zsh wrapper adds them when
a session starts. Copilot, Cursor, OpenCode, and Codex rewrite their own
config files, so Nix merges its settings into them on activation instead of
symlinking.
