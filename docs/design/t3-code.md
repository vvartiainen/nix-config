# T3 Code settings

How T3 Code's preferences are owned here and why. Everyday use is in
[agent configuration](../agents/config.md#t3-code-settings).

## Declared values, app-owned state

T3 Code rewrites `~/.t3/userdata/settings.json` and `client-settings.json`
while it runs, so activation merges the values declared in
[`t3-code.nix`](../../nix/modules/home/programs/ai/clients/t3-code.nix) into
those files instead of linking them. Declared keys are written, app-managed keys
are kept, and a declaration removed from Nix is dropped on the next activation.
Merge state is recorded under `~/.local/state/nix-config/merged/`, so activation preserves
app-owned keys from the file it reads. Close T3 before applying to avoid
concurrent writes; a declared value changed in the app returns to the Nix value
on the next switch.

Per-project settings stay app-owned. T3 keys them by a project id generated in
its own database, so a declaration cannot name the projects that will exist or
survive one being re-added. The environment-wide default covers every project
instead, and a per-project override still wins over it.

## Pull request merge method

`pullRequestMergeMethod = "rebase"` is the environment default. The homelab
repositories allow rebase merges only, so this is not what makes a merge rebase:
it declares the intent and decides the method on a host or project that allows
more than one. T3 preselects the first method that is still allowed, in this
order: the method already chosen for that pull request, the project's default,
the last method used, then the host's first allowed method. With one allowed
method the host alone decides, so the declaration is explicit rather than
load-bearing; a host that later offered several would land on the declared
method instead of its first.

Merging outside T3 Code needs the same method. `fj pr merge -M rebase` rebases,
while `fj pr merge` without `-M` asks the host for a merge commit, which it
refuses. The server side is owned by the homelab repository and described in its
`docs/services/forgejo.md#branch-protection` and `docs/design/forgejo.md`; the
client side is owned here. See
[merge behavior](../../AGENTS.md#working-conventions).
