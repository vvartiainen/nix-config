---
name: handoff
description: Prepare an evidence-based end-of-work handoff covering changes, commits, backlog activity, permissions, deviations, verification and remaining user actions.
---

# Handoff

Read repository instructions and the project's handoff/review policy. Use the
session record, Git status/diff/log and task records as evidence. Do not infer
session activity from timestamps or claim other people's changes as your own.
Do not restart completed implementation just because a handoff is requested.

Finish authorized work and relevant checks before handing over. If interrupted
or blocked, state that work is partial and preserve enough context to resume.
Commit only session-owned changes when required/authorized by repository policy;
never stage unrelated files or push as part of a handoff.

## Gather

- Original request, accepted clarifications and final delivered behavior.
- Files/areas changed, why, user-visible effects, compatibility or migration
  implications, and known risks. Identify unrelated pre-existing work separately.
- Branch and final HEAD, session commits (short SHA and subject), uncommitted
  work, and remote publication state only when verified.
- Permission prompts, sandbox/network blocks, automatic approval rejections,
  failed commands and their resolution or remaining impact. Report “none” when
  none occurred. Do not disguise a blocked check as a successful one.
- Every backlog task created, materially edited, implemented, reopened, closed
  or archived: ID/title, action, initial/final status, remaining review. Include
  the handoff task itself. State explicitly when none were closed or archived.
- Deviations from the original spec: what changed, why and authorization. State
  “none” when applicable; do not invent approval or bury incomplete scope.
- Verification: exact check/command or manual exercise, result, tested revision,
  and scope/limits. Separate passed, failed, blocked and not run. A check before
  a later change is not evidence for that change without justification.
- Manual steps: prerequisites, concrete action, expected result, and what the
  user should record. Separate required acceptance from optional suggestions.
- Remaining blockers/decisions, next action and owner. Include rollback/recovery
  instructions when operational or history changes make them useful.

## Persist and report

Follow the project's backlog workflow using the configured tools. Search before
creating a handoff; update the same session's record on continuation. Preserve
existing labels. Check only evidence-supported acceptance criteria; user review
items remain unchecked. Do not mark work Done, archive tasks or remove review
labels where project policy reserves those actions for the user. If no backlog
is configured, provide the handoff in the response without inventing a tracker.

Keep durable detail in the project's handoff record and link affected tasks and
commits. Never copy secrets/private identities into handoff artifacts. If task
updates are blocked, include the intended updates in the response and say they
were not saved.

Use this outline, scaling detail to the work. Keep the final response concise
but self-contained; link durable evidence for longer sessions.

```markdown
Changes: <outcome, why, affected files; completed or partial>
Commits: <SHA — subject; branch/HEAD and uncommitted work>
Spec deviations: <none, or change/reason/authorization>
Permissions/issues: <none, or prompt/block, resolution and impact>
Verification: <check — result — revision/scope/limits>
Manual verification: <action → expected result; owner>
Risks/recovery: <known limits and recovery where relevant>
Backlog:
| Task | Action | Status before → after | User review |
| --- | --- | --- | --- |
| <ID — title> | <action> | <status> | <exact action> |
Next: <one concrete step and owner>
```
