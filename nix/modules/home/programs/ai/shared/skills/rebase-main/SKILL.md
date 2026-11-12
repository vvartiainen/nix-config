---
name: rebase-main
description: Rebase the current feature branch onto main and verify linear history. Use when asked to update a branch from main or remove merge commits through a rebase.
---

# Rebase onto main

Read repository instructions. An invocation authorizes a local rebase, not a
push, force-push, reset, unrelated cleanup or dependency update.

## Prepare

1. Inspect status, current branch, upstream, worktrees and any ongoing Git
   operation. Do not start inside an existing merge/rebase/cherry-pick, on a
   detached HEAD, or on main itself; explain the state and resolve the intended
   branch with the user. Do not continue another session's operation silently.
2. Require a clean index and worktree. Do not discard, auto-stash, or commit
   unrelated user changes. If dirty, pause the rebase and explain what needs
   preserving; continue only under an agreed preservation approach.
3. Identify the correct main ref from repository guidance and remotes. Fetch
   that remote's main branch when permitted, and pin the resulting commit ID.
   Do not assume origin is correct in a fork or silently use stale local main
   when the request requires the latest remote state. If fetch is blocked,
   report the block and obtain a decision before using a cached base.
4. Inspect branch-only commits, merge topology and whether they are shared.
   A request to rebase a known shared branch authorizes rewriting it locally;
   if sharing was unexpected, explain the affected commits before proceeding.
   Never rebase unrelated branches. For stacked/diverged histories or ambiguous
   old bases, determine the intended commit set before selecting --onto.
5. Record old HEAD and base IDs and create a uniquely named local backup ref.
   Report this recovery ref; never overwrite an existing ref. Record the old
   commit list for comparison and any meaningful merge-resolution changes.

## Rebase

For an ordinary feature branch, use a standard rebase onto the pinned main
commit. Do not use --rebase-merges when linear history was requested. Preserve
logical commits and messages; do not squash or edit authorship without a reason
within the request. Inspect merges first so unique merge-resolution changes
are not lost when their commits are flattened.

Resolve conflicts using both intended behavior and the updated main code.
Stage only resolved paths and continue noninteractively. Never choose ours or
theirs for the entire rebase indiscriminately. Do not skip commits to silence
conflicts; explain any commit Git drops as already applied or empty. If intent
cannot be determined, stop at the conflict, list affected paths and the needed
decision without exposing sensitive content. State whether the rebase remains
in progress. If this session's rebase must be abandoned, use rebase --abort and
verify restoration; do not reset away user changes.

## Verify and hand over

- Confirm main's pinned commit is an ancestor of HEAD and the branch-only range
  contains no merge commits. Check clean status and that the rebase completed.
- Compare old/new commit series with range-diff and inspect the tree changes
  and any dropped commits. Explain intended upstream changes versus conflict
  resolutions. Run the checks required by the repository for affected behavior.
- Report old/new HEAD, pinned base, backup ref, conflict resolutions, dropped
  commits, checks/results and remaining manual verification. Explain recovery
  via the backup ref without performing a destructive reset.
- Leave publishing to the user unless separately authorized. Mention when a
  previously published branch now requires a coordinated history update. If
  pushing is explicitly requested, follow project policy and prefer an explicit
  expected remote SHA with --force-with-lease; never use plain --force.
