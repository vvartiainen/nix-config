---
name: agent-planning
description: Turn a user's goal or existing handoff into an actionable agent work plan with isolated temporary workspaces, work notes, task briefs, review steps and a continuation prompt. Use when asked to plan substantial agent work across tasks, sessions or repositories.
---

# Agent planning

Start from the user's prompt: a goal, rough idea, existing plan or handoff.
Research the actual repositories and prepare a plan another session can pick up
without the conversation. Scale the detail to the work; a small change does not
need multiple agents, integration branches or a directory full of notes.

Planning alone does not authorize implementation or launching agents. If the
user also requests execution, continue within that scope after planning; do not
add an approval stop unless required by project policy or an unresolved decision.
When this skill is used during execution, keep the same plan and notes current.

## Establish the current state

- Read applicable project instructions, existing design/contract documents and
  relevant source. Consult configured project trackers and their workflow before
  writing task records. Reuse existing tasks and documents rather than creating
  a parallel source of truth. If unavailable, say where the draft is saved and
  which tracker updates remain unsaved.
- Inspect repository status, branches, HEAD and relevant commits. Distinguish
  committed work, unrelated local edits, verified publication state and deployed
  state. A previous handoff is context to verify, not proof of current state.
- Record scope, observable acceptance criteria, constraints and open decisions.
  Ask only for information that materially changes the plan; continue independent
  research while waiting. Label assumptions and unknowns rather than guessing.
- Identify repository access, tools, permissions and validation capabilities.
  Planning can inspect these without creating implementation worktrees. During
  execution, verify access before dispatch; worktrees require writes to the
  source repository's Git metadata even when their checkout is under `/tmp`.

## Working layout and notes

Choose one unique temporary root for the effort, such as a directory created by
`mktemp -d /tmp/agent-work.XXXXXX`. Record its actual absolute path. Reuse that
root when resuming the same effort; do not overwrite another session's workspace.

```text
<root>/
  plan.md                     working plan and current state
  wt/<repo>-<task>/           isolated checkout per implementation task
  wt/<repo>-integration/      optional checkout for combining reviewed tasks
  notes/<task>-brief.md       self-contained task instructions
  notes/<task>-result.md      changes, commits, checks and remaining gaps
  notes/<task>-review.md      review findings and disposition
```

Create only the directories and notes needed now. Keep a short index in
`plan.md`: authoritative task/document references, repository paths, selected
base commit IDs, workspace/branch mappings, dependencies, progress and next step.
Update notes at meaningful checkpoints, before context loss and before reporting
completion. Include exact commands, results and the revision tested; distinguish
passed, failed, blocked and not run. Keep secrets out of all artifacts.

Temporary storage is disposable. A commit in a linked worktree normally survives
loss of its temporary checkout because Git objects live in the source repository.
Uncommitted files and notes do not. Before a handoff, persist the necessary plan,
results and continuation prompt in the project's designated tracker or durable
location; `/tmp` must never be the only copy of essential handoff information.
Respect projects that keep work notes out of repository documentation.

Prefer linked worktrees from an explicitly selected committed base. Preserve
unrelated edits in existing checkouts. Use unique branch names that identify
the effort and task; do not assume `main` or reuse an existing integration branch
without inspecting its ownership and history. Record any earlier prerequisite
commits required by the selected base.

If a permission block prevents worktree creation, follow the environment's
escalation rules. A local clone is an alternative only when permitted; never use
it to bypass a denied action. Record its source and branch. Commits inside a
temporary clone remain temporary until fetched into a durable repository. Give
an exact retrieval command, for example `git -C <durable-repo> fetch
<temporary-clone> <branch>:<new-durable-branch>`, and verify the retrieved commit
before cleanup. Do not claim the clone is safely preserved merely because it
contains commits.

## Divide the work

Prefer a few independently reviewable tasks. Each needs a concrete result,
acceptance checks, repository, starting files, dependencies and validation limits.
Separate interface decisions from their consumers. Group independent tasks into
waves; dependent work starts from reviewed prerequisite commits, not a stale base.
Split a task if its brief cannot fit a focused working session.

Use a compact table where it helps:

| ID | Repository | Result | Dependencies | Base / branch | Validation |
| --- | --- | --- | --- | --- | --- |
| <id> | <repo> | <observable outcome> | <ids or none> | <commits / branch> | <checks> |

Parallel agents are optional and require authorization under the active
instructions. Otherwise use these same briefs sequentially in the current
session. Do not spawn agents merely because the plan contains parallel waves.
Avoid overlapping file ownership; identify a single integration owner where
tasks must change shared files or interfaces.

Every implementation brief must contain:

- Goal, scope, exclusions, acceptance criteria and dependency state.
- Exact repository, allowed worktree path, branch and base commit; work only in
  that checkout and preserve other people's changes.
- Applicable instructions, authoritative tasks/designs and starting source files.
- Interface contracts and decisions the task may or may not change.
- Exact project validation commands, permitted environment and verification gaps.
- Commit/staging rules from project policy. When commits are authorized, commit
  owned work before reporting; record any work that could not be committed.
- Delivery boundaries, including push, deploy or external actions only if authorized.
- Result-note path and report: changes, commit IDs, real check results, remaining
  risks, questions and user-only verification. Mark unknown claims explicitly.

Carry forward applicable shell and sandbox rules, not machine-specific commands
from an old example. Do not embed private identities or credentials in briefs.

## Review and integration

For execution, inspect each submitted diff and commit history against the brief.
Check acceptance evidence and rerun appropriate validation; a worker's report
does not replace review. Record findings and fixes in the review note. Do not
merge work with unresolved material findings.

When multiple branches need combining, use a separate integration checkout per
repository from the recorded base. Follow project history policy for merge,
rebase or cherry-pick; do not impose merge commits on a linear-history project.
Record incorporated commit IDs and rerun checks on the integrated result.
Validate cross-repository consumers against those exact revisions using the
project's supported local overrides. Do not silently publish dependencies to
make integration work.

Distinguish static checks, evaluation, builds and runtime verification. Record
what the current environment cannot establish, with the concrete user action
and expected result. Leave unsupported acceptance criteria unchecked. Keep
tracker status and user-review obligations consistent with project policy.

## Deliver the plan or continuation handoff

Persist a compact record containing:

1. Goal and authoritative task/design references.
2. Verified state: repositories, bases, branches, commits, uncommitted work and
   publication/deployment state where checked.
3. Prerequisites and unresolved decisions, separating those needed to start from
   those needed later.
4. Actual temporary layout, durable note location and recovery/retrieval steps.
5. Tasks, dependency waves, briefs and acceptance checks.
6. Review/integration procedure and validation limits.
7. Current progress, blockers, next action and owner.
8. A copyable prompt for a new session.

Use this prompt shape, filling in verified values and removing unused sections:

```text
Read <durable plan/handoff> and the linked project instructions and task records.
Goal: <user's requested outcome>.
Repositories: <paths and identities>; existing workspace: <root, if still present>.
First verify current Git state, prerequisite commits and workspace availability.
If temporary files are missing, reconstruct from <durable records and branches>.
Start/resume <specific task or wave> from <base/dependency commits>.
<Use sequential work, or the explicitly authorized delegation arrangement.>
Follow the briefs, preserve unrelated work, record results and review each diff.
Validate <checks and integration procedure>; report <defined checkpoint>.
Limits: <authorization boundaries and checks reserved for the user>.
Open decisions: <questions that still require an answer, or none>.
```

Report what was actually prepared or executed and where it is saved. Suggest
improvements separately when they extend the user's scope. Do not delete source
handoffs or temporary work until useful notes and commits are durably preserved
and cleanup is authorized; never remove unrelated files or active worktrees.
