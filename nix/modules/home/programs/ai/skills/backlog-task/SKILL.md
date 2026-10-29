---
name: backlog-task
description: Create or refine a Backlog.md task using a minimal intent-focused template. Use when asked to capture work in the backlog or write a concise task with clear acceptance criteria.
---

# Minimal Backlog task

Read the configured Backlog.md workflow overview, task-creation guide and any
project review policy before changing tasks. Use the project's MCP tools or
documented CLI; do not edit task Markdown behind the tracker. If no tracker is
available, provide a draft and clearly say it has not been saved.

Search for existing work first and read likely matches. Update an existing task
when appropriate rather than creating a duplicate; preserve unrelated scope,
labels and checked criteria. Ask only for missing intent that materially affects
the task. Do not create speculative follow-up work beyond the user's request.

For one focused change, default to this template:

```markdown
Title: <verb + observable outcome>

Why: <1–2 sentences: current problem/trigger and why it matters>

Acceptance criteria:
- [ ] <observable behavior or result>
- [ ] <important boundary/failure behavior, if relevant>
- [ ] <required verification or documentation, if relevant>
```

Keep only useful criteria, usually 1–3. Each must be independently verifiable;
do not pad the task with generic checklist items. Replace placeholders with
concrete intent. Include enough context for someone who has not seen the chat.
Avoid file-by-file implementation plans, speculative designs and requirements
invented during task creation. Research and record the implementation plan
when execution starts, according to the workflow.

Add priority, dependencies, references, documentation, type, owner or labels only
when known or required by project policy. Leave future work To Do unless the
workflow says otherwise. Use Draft only when explicitly appropriate; do not mark
a newly captured task Done. Apply required review labels and handoff obligations.
Reuse project Definition of Done defaults instead of duplicating them as criteria.

If the request truly needs independently deliverable tasks, explain that split
and follow the project's task-structure rules. Do not turn a small request into
a hierarchy just to fill a template.

After saving, report the task ID/title, why, criteria and status concisely. If
refining a task, state what changed. Task creation alone does not authorize
implementing the task.
