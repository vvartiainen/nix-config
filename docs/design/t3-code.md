# T3 Code settings

Everyday use is in [agent configuration](../agents/config.md#t3-code-settings).

## Declared values, app-owned state

T3 Code rewrites its settings files while running, so activation merges the
declared values from
[`t3-code.nix`](../../nix/modules/home/programs/ai/clients/t3-code.nix) into
them instead of linking them: declared keys are written, others are kept, and
removed declarations are dropped.

Per-project settings stay app-owned, because T3 keys them by ids from its own
database. Declare environment-wide defaults instead; a per-project override
still wins.

## Pull request merge method

`pullRequestMergeMethod = "rebase"` matches the rebase-only Forgejo
repositories. Outside T3, merge with `fj pr merge -M rebase`; without `-M` it
asks for a merge commit and is refused.
