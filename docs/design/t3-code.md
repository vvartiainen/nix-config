# T3 Code settings

How T3 Code's preferences are owned here and why. Everyday use is in
[agent configuration](../agents/config.md#t3-code-settings).

## Declared values, app-owned state

T3 Code rewrites its settings files while it runs, so activation merges the
values declared in
[`t3-code.nix`](../../nix/modules/home/programs/ai/clients/t3-code.nix) into
them instead of linking them. Declared keys are written, app-managed keys are
kept, and a declaration removed from Nix is dropped on the next activation.
Closing T3 before applying avoids concurrent writes; a declared value changed
in the app returns to the Nix value on the next switch.

Per-project settings stay app-owned. T3 keys them by a project id generated in
its own database, so a declaration cannot name projects that do not exist yet
or survive one being re-added. The environment-wide default covers every
project instead, and a per-project override still wins over it.

## Pull request merge method

`pullRequestMergeMethod = "rebase"` is the environment default. The homelab
repositories allow rebase merges only, so with one allowed method the host
decides and the declaration only states the intent. It matters on a host that
allows several methods, where T3 would otherwise fall back to the last-used
method or the host's first.

Merging outside T3 Code needs the same method: `fj pr merge -M rebase`, since
`fj pr merge` without `-M` asks for a merge commit and is refused. The homelab
repository owns the server side in its `docs/services/forgejo.md#branch-protection`
and `docs/design/forgejo.md`.
