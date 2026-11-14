# Agent quotas, status and history

## Quotas

[Global shortcuts](../keybindings.md#global-shortcuts) open CodexBar or the separate
Metrics dashboard. CodexBar needs to be running. In Metrics, **Esc, Q, Ctrl+C
or Cmd+W** hides the dashboard; **R** refreshes, **Ctrl+D** stops it. It hides
on focus loss. Last successful reports stay visible while independent refreshes
run; report ages and errors show stale data. Stop and reopen after dashboard
changes. Codex needs its OAuth login; Claude Code must be installed and signed in.
For repeated Claude credential prompts in CodexBar, choose **Providers → Claude →
Usage source → CLI** to avoid repeated Keychain re-grants.

## Status in the terminal

Kitty tab labels show the repository or `repository:worktree`; manual names
win. Codex, Claude Code and Copilot CLI report their own working and waiting
status to the terminal; no hooks are needed.

## Session history

Claude, Codex and Pi JSONL sessions are copied hourly into
`~/.local/share/agent-transcripts/<host>/`; source deletions do not delete the
archive. Run `agent-transcripts-archive` to sync now; its log is
`~/Library/Logs/agent-transcripts-archive.log`.
`agentsview` provides local session search and analytics; use `--offline` to
avoid fetching model prices.

After [upload setup](../runbooks/agent-transcript-uploads.md), a separate hourly
job refreshes the archive and uploads Claude, Codex and Pi JSONL files to the
homelab AgentsView. Run `agent-transcripts-upload` to upload now, or add
`--dry-run` to preview transfers. Remote files are never deleted.
An unconfigured or unreachable endpoint is skipped silently and retried next
hour. Reachable-server authentication and transfer failures exit with an error;
check `~/Library/Logs/agent-transcripts-upload.log`. A failed reachability check
also skips server outages; there are no alerts or metrics yet.
