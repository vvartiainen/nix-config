---
name: work-on-task
description: Work on a Backlog.md task by ID or title, or prepare a task brief to give another agent. Use when asked to implement a named task, pick up a ticket, or hand a task to an agent.
---

# Work on a task

Accept a task ID or title, optionally a project and an explicit mode:

- `work-on-task TASK-123`: resolve and implement the task in this agent session.
- `work-on-task "Fix the startup failure"`: resolve the title, then implement.
- `work-on-task prepare TASK-123`: produce a dispatch brief only; do not start
  implementation, claim ownership or launch an agent.

Default to direct execution when asked to work on a task. Preparing a brief is
not execution. Do not spawn agents, provision a VM or send messages merely
because the skill is invoked. If the user explicitly requests a launch, use
only the verified launcher and environment contract below; report what actually
started. A prompt or recorded assignee does not prove an agent was launched.

## Resolve before acting

1. Read repository instructions, configured Backlog workflow overview and
   project-specific execution, review and handoff policy. Select the backlog
   from explicit project context or verified repository mapping. Do not guess
   across backlogs when the project is ambiguous.
2. Fetch an ID directly, or search by title and read the matching task. Prefer
   an exact unique title. If multiple plausible matches remain, present their
   IDs/titles and ask which one; never silently choose a fuzzy match.
3. Read the full description, acceptance criteria, dependencies, status, notes,
   references, subtasks and existing plan. Report the resolved ID/title. A title
   is a lookup key, not a sufficient implementation specification.
4. Verify the repository and branch/worktree match the task. Inspect existing
   changes and preserve unrelated work. Follow project isolation conventions;
   do not create a checkout from an assumed base or overwrite someone else's
   work. Determine which checks this environment can actually perform.
5. Resolve dependencies by reading their records. Unknown task IDs and missing
   dependencies are unresolved, not satisfied. Check for active owners or
   sessions before claiming work; an In Progress task is not automatically
   available. Resume your own known work, or clarify ownership when needed.
6. Do not restart an archived, completed, review-only or already implemented
   task awaiting user acceptance without explicit direction. Follow the task's
   review policy rather than interpreting every open status as unfinished code.

## Execute

Read the execution guide, take ownership and set status according to project
policy. Research the current implementation, then record the implementation
plan in the task before editing files. An older plan is context to reassess,
not proof that its commands, paths or design still apply. Obtain plan approval
only where required by the workflow or a material unresolved decision.

Implement the resolved scope and approved clarifications. A request for one task
does not automatically include every linked task or subtask. If the user asks
for all subtasks, respect dependencies and keep evidence on each record.
Keep progress and blockers current in the tracker. Do not expand the task or
create speculative follow-ups without authorization.

Run the repository's required checks. Follow sandbox escalation rules; do not
weaken permissions, install tools, read credentials, apply systems or bypass
failed approvals to complete the task. When the execution environment cannot
verify a platform-specific behavior, record the gap and exact manual check.

Finish authorized work, commit when required, and follow the finalization and
handoff workflow. Check only criteria supported by evidence. Leave user review
and completion to the user where the project requires it. Report changes,
commits, task updates, permission blocks, verification and remaining actions;
use the `handoff` skill when available. Do not push unless authorized.

## Prepare a brief for another agent

Resolve and read the task as above, but leave status/ownership unchanged in
prepare mode. Put durable scope in the tracker; do not copy private material
into shell commands. Provide this compact prompt with actual IDs and context:

```text
Use work-on-task for <project> <TASK-ID> — <exact title>.
Repository: <verified repository identity; base/branch if specified>.
Read the current task and project instructions before starting. The task is
the source of scope and acceptance criteria; reassess its plan before editing.
Dependencies/ownership: <verified state or unresolved blocker>.
Environment: <verified launcher/profile or "provisioning not configured">.
Constraints: <important task-specific constraints and verification limits>.
Deliver the implementation, required checks and commits under project policy,
then update the task and provide a review handoff. Leave user acceptance open.
```

An agent must be able to read the skill, repository instructions and authoritative
task record in its target environment. Confirm those capabilities before an
explicitly requested launch; if unavailable, provide a brief and explain the
missing capability instead of claiming dispatch succeeded. Do not interpolate
task titles or descriptions as executable shell text.

## Agent-sandbox integration

Known from nix-config's `ai/mcp.nix` and Backlog TASK-53.2 at authoring time:

- The separate agent-sandbox project has guests with MCP entries shared with
  nix-config's catalog. `nixos` runs `mcp-nixos`; `backlog-<project>` runs
  `bl <project> mcp start`. Duplicate entries with different definitions have
  caused scope conflicts. Verify current definitions before using them.
- A private tools flake can supply nix-config modules to the sandbox. It is
  external configuration, not a provisioner defined by this skill. Do not read
  private host/tools config just to dispatch a task.
- Local AI CLI permission sandboxes documented in nix-config are a separate
  layer from the agent-sandbox guest. Do not infer VM mounts, network, secrets,
  installed skills or launcher syntax from the local CLI permissions.

The agent-sandbox source could not be inspected when this skill was authored.
Provisioning and launch commands are intentionally unspecified. Fill in this
contract from its actual documentation before enabling automatic launch:

```text
Launcher/provisioning command and source documentation: <fill in>
Existing sandbox reuse and readiness check: <fill in>
Agent CLI/model/profile selection: <fill in>
Repository checkout/base/branch, guest path and writable boundaries: <fill in>
Skill delivery and agent startup/reload: <fill in>
Backlog MCP access/project mapping (and duplicate-scope handling): <fill in>
Credentials/network policy (references only; never credential values): <fill in>
Prompt transport/quoting and session/task identity: <fill in>
Session status/logs, resume/failure handling and cancellation: <fill in>
Result retrieval, commit/branch ownership and cleanup policy: <fill in>
```

Until configured, invoke this skill inside an already provisioned agent or use
prepare mode to get a copyable brief. Missing provisioning does not prevent
normal task execution in a suitable existing session.
