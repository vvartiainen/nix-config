# Agent quotas, status and history

## Quotas

[Global shortcuts](../keybindings.md#global-shortcuts) open CodexBar (must be
running) or the Metrics dashboard. In Metrics, **Esc**, **Q** or **Cmd+W**
hides it, **R** refreshes and **Ctrl+D** stops it. Codex and Claude Code must
be signed in. If CodexBar keeps asking for Claude credentials, set
**Providers → Claude → Usage source → CLI**.

## Status in the terminal

Kitty tab labels show the repository or `repository:worktree`; manual names
win. Codex, Claude Code and Copilot report working and waiting status
themselves.

## Session history

Claude, Codex and Pi sessions are copied hourly into
`~/.local/share/agent-transcripts/<host>/`, keeping files deleted at the
source.

```sh
agent-transcripts-archive              # sync now
agent-transcripts-upload --dry-run     # preview the homelab upload
agent-transcripts-upload               # upload now
agentsview --offline                   # local search and analytics
```

Uploads need [setup](../runbooks/agent-transcript-uploads.md), run hourly and
never delete remote files. An unreachable server is skipped silently. Logs:
`~/Library/Logs/agent-transcripts-archive.log` and
`~/Library/Logs/agent-transcripts-upload.log`.
