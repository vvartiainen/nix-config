# nix-config

## Description

This repository contains my macOS configs using nix, nix-darwin and home-manager.

## Validation commands (no apply)

Choose validation according to the change:

- Run `just lint` for fast read-only checks on staged, unstaged and untracked
  files. Use `just lint --base <revision>` to include committed changes, or
  `just lint --all` to audit all owned files. Add `--format` for formatting
  checks; formatting is opt-in until the existing files have a consistent baseline.
- Run `just lint --tests` to include fast behavior suites for code changes,
  or `just test-fast` to run those suites regardless of changed files.
  Full dependency-backed and macOS runtime suites are separate; see
  [maintenance](docs/maintenance.md#repository-checks). They never apply the system.
- Documentation: review the diff and run `git diff --check`.
- Directly linked dotfiles and helper scripts: run relevant syntax or behavior
  checks and `git diff --check`; no system build is needed.
- Nix modules: run `statix check .`, fixture evaluation and `git diff --check`.
- Package, dependency, activation or build changes: also run a fixture system
  build. Build whenever evaluation leaves a concrete concern unresolved.
- Sandboxed Pi cannot run Nix commands that reach the daemon, so it runs
  `statix`, `nixfmt` and `just lint` and hands fixture evaluation and builds to
  the user; see [Pi's limits](docs/agents/permissions.md#pi).

Codex, Claude and Copilot stop hooks run the same fast checks, including fast
behavior suites after code changes and commits made since the current prompt.
They never fix files, evaluate Nix, build or apply. A failure asks the agent to
address its changes once; report pre-existing issues and missing tools without
changing unrelated files. Hooks do not replace the scoped validation below.

Use the tracked `nix/fixtures/host` input for Nix verification. Run commands
from the repository root. Do not run `just init-host` or migrate host data to
make validation work. For module evaluation without building:

```sh
statix check .
nix eval --raw '.#darwinConfigurations.agent-fixture.system.drvPath' \
  --override-input host "path:$PWD/nix/fixtures/host"
```

Evaluation checks module evaluation and derivation generation. It does not
build generated files or verify application behavior. Inspect relevant evaluated
options when checking generated configuration; use targeted application checks
for runtime behavior.

When a system build is required:

```sh
nix build --no-link '.#darwinConfigurations.agent-fixture.system' \
  --override-input host "path:$PWD/nix/fixtures/host"
```

The fixture contains only synthetic identity and paths, with nested
virtualization disabled and no private modules. Its `repoRoot` is a synthetic
path for generated dotfile links and does not need to exist. Never apply the
fixture system or change `flake.lock` for it. Do not read
`~/.config/nix-config-host` or request access to it for routine validation.
Pass the fixture override on every Nix invocation; it implies
`--no-write-lock-file`. Never commit real host names, usernames or
work-specific config to this repo. New files must be `git add`ed before Nix
evaluation or builds see them.

`nix flake show` is optional output inspection. `nix flake check` does not
validate `darwinConfigurations`; this flake currently exposes no `checks`.
Neither replaces an explicit system evaluation or build.

Host-specific `just` recipes use private host data and are for the user's manual
validation. Agents use `just lint` and the direct Nix commands above. Direct
`nix build --no-link` leaves no result symlink. Report that fixture verification
covers public configuration only; private modules, real identity and nested
virtualization require manual host validation.

Do not run apply commands (for example `just switch <hostName>` or
`darwin-rebuild switch`); user applies manually.

## Agent sandbox

Commands run in an OS sandbox (see
[sandbox usage](docs/agents/permissions.md#working-in-the-sandboxes)).
For T3 mode selection and approval behavior, follow the
[provider permission mode guidance](docs/agents/permissions.md#t3-code-permission-modes).

- Writable in terminal sandboxes: the workspace, `$TMPDIR`, `/tmp`, and
  `~/.cache/<tool>-agent`. T3 Codex uses managed writable roots; inherited
  cache variables do not grant writes. For cache variables, see
  [cache variables](docs/agents/permissions.md#working-in-the-sandboxes).
  Use `/tmp` for scratch files.
  Nix refuses `--output-lock-file` and `--reference-lock-file` paths through
  the `/tmp` symlink; pass `/private/tmp/...` instead.
- Flake update previews: use the fixed `flake-update-preview [input ...]` wrapper
  to preview the flake files embedded in the applied configuration, independent
  of the working directory; see [permissions](docs/agents/permissions.md#flake-update-previews).
  Raw `nix flake update` remains reviewed.
- Network: terminal Codex and Pi allow ordinary internet access; T3 Codex uses
  its active managed policy. Claude, Cursor and Copilot allow package hosts,
  `api.github.com` and `raw.githubusercontent.com`; other domains need review.
  Host allowances are not upload filters; keep secrets out of exported variables
  and readable project files. See [network boundaries](docs/agents/permissions.md#working-in-the-sandboxes).
- Nix builds and `nix fmt` require review for host-daemon delegation. Fixture
  evaluation can run sandboxed in terminal Codex and Claude; T3 Codex may need
  escalation for caches or daemon access. Pi cannot reach the daemon in any
  mode, including T3 Full access; recipes that invoke Nix fail there too.
- Codex and Claude Code run routine project commands inside their sandboxes
  without prompts; Copilot requires normal approval for unlisted commands.
  Claude excludes `gh` and Rex from its sandbox; Rex requires approval.
  Reviewed sandbox escapes may run other commands outside it.
- `Operation not permitted`, `403`/`Forbidden`, or `x509: OSStatus -26276`
  mean the sandbox blocked it: retry once with escalation or ask, don't try
  variants or work around it.
- Use `agent-git` for local worktree add/move/remove, merged branch deletion
  and upstream changes; see [local Git maintenance](docs/agents/permissions.md#local-git-maintenance).
  It manages only `<main>/.agent-worktrees`; never remove another live T3
  thread's worktree. T3 Codex may still require host approval for the helper.
- Git over SSH, `fj`, and raw worktree operations outside the session's own
  worktree run outside the sandbox with approval, and `allowed_domains` does not
  cover SSH. Claude runs a standalone `git push` outside its sandbox after one
  prompt; do not retry it with `allowed_domains`. Pi is the exception: it
  reaches the SSH agent socket and an agent-only forge token inside its own
  sandbox.
- For read-only `gh`/`fj` views and Claude's reviewed fetch hook,
  follow the [standalone command rules](docs/agents/permissions.md#working-in-the-sandboxes). Add sibling repositories to the session before writing to them.
- For `fj` repository discovery, follow
  [Forgejo discovery](docs/agents/permissions.md#forgejo-repository-discovery).
- Linked worktrees can also need approval for `git add` or `git commit` when
  their index/shared Git metadata is outside the writable roots. Escalate the
  exact Git command after a denial; do not change metadata permissions.
- Scan for secrets with `agent-betterleaks`, not `betterleaks`, which crashes
  in the sandbox; see [files](docs/agents/permissions.md#files).
- Credentials (`~/.ssh`, `~/.aws`, `.env`, keys) and tool installs
  (`mise install`) are off-limits; ask the user.
- Avoid interactive commands; pass non-interactive flags.

## Additional validation constraints

- Test direct Home Manager imports with small temporary consumer flakes pinned
  to this checkout and its existing inputs. Keep locks, results and generic users
  outside this repo.
- Do not rerun a permission-blocked formatter when the user has asked to skip
  formatting. Keep edits readable and run `git diff --check`.
- For helper scripts, check `type -a python3` and prefer an installed executable
  over a mise shim when it emits unrelated cache/state permission warnings.
  Do not change tool-manager permissions just to hide logs.
- macOS sandbox runtime tests need reviewed execution outside the agent sandbox.
  Use synthetic sockets and bind each tested host address before probing it;
  skip unassigned addresses instead of changing the Mac's network interfaces.

## Working conventions

- Prefer declarative configuration for everything
- Check existing documentation, also using MCP if such exists
- Keep module boundaries clear: one program per file in
  `nix/modules/home/programs/` or `nix/modules/darwin/programs/`, importable
  on its own; host files only compose and set host facts.
- Keep changes minimal and easy to review
- Prefer updating existing modules/files over adding new abstractions
- Only update `flake.lock` when dependency updates are intentional
- Commit the changes, push them as a new branch to `origin` (Forgejo) and open
  a pull request
  - Start each task's branch from a freshly fetched `origin/main`, not the
    worktree's current branch: cleanups reset worktrees after a merge.
    `git fetch origin`, then `git switch --no-track -c <branch> origin/main`.
  - Use the existing commit style: conventional commits, short message, no
    long descriptions, no trailers such as Co-Authored-By or Claude-Session.
  - Push with `git push origin <branch>` and open the pull request with
    `fj pr create -r '<forge-host>/<owner>/<repo>' --base main --head <branch> --body-file <file> "<title>"`.
    Sandboxed Git config is read-only, so `git push -u` can publish the
    branch while failing to record its upstream. Reviewed pushes outside the
    sandbox can record it. Push without `-u`; where an upstream is
    needed, use
    `agent-git branch --set-upstream-to origin/<branch> <branch>` ([local Git
    maintenance](docs/agents/permissions.md#local-git-maintenance)). Pi's `fj`
    takes `-r '<owner>/<repo>'` without the host.
  - Merge by rebase: the Forgejo repositories allow rebase merges only, and an
    outdated branch does not block (conflicts and required checks still can).
    A hand merge is `fj pr merge -M rebase`; without `-M` it asks for a merge
    commit and is refused, so never retry it without `-M`. T3 Code defaults to
    rebase too ([why](docs/design/t3-code.md#pull-request-merge-method)).
  - Write the body with the sections of
    [the PR template](.forgejo/pull_request_template.md), keeping its
    headings and order. Forgejo fills it in only in the web UI;
    `fj pr create --body-file` does not apply it. Write "None" for sections
    that do not apply instead of dropping them.
  - Write issue bodies with the sections of the
    [task](.forgejo/issue_template/task.md) or
    [bug](.forgejo/issue_template/bug.md) template, dropping those that do not
    apply; `fj issue create --body-file` does not apply them either. Because
    the repository has issue templates, pass `--no-template` with
    `--body-file`; without it `fj` refuses to create the issue.
  - Group issues with labels: create one with
    `fj repo labels create <name> <hex-color> -d "<description>"` and apply
    labels with `fj issue edit <number> labels -a <label> [-a <label>]`.
    These commands take no `-r`; with several remotes and no upstream they
    cannot find the repository, so first run
    `agent-git branch --set-upstream-to origin/main <branch>`.
  - In T3, link the pull request to the thread; see
    [T3 Code settings](docs/agents/config.md#t3-code-settings).
  - Push only to `origin`. Pushing to the public `github` mirror stays with
    the user, after a pre-push review.
- At the end of implementation tasks summarize the changes in the final
  response with the same sections as the PR template.
- Also inform if you ran into some permission issues that could be fixed
- Clearly list any commands the user must run manually in the final response,
  using copyable code blocks with the required working directory and purpose.
  Distinguish remaining commands from commands already completed.
- Propose AGENTS.md improvements if you ran into permission issues and had to workaround them

## Documentation

Layout of `docs/`:

- Top level (`maintenance.md`, `keybindings.md`): everyday pages with commands,
  tables and quick checks. Keep them short; no reasoning and no one-time setup.
- `programs/<program>.md`: everyday use of one program or area: how to use it,
  reload it, update it and fix known problems.
- `agents/`: everyday use of the coding agents: permissions, configuration,
  keybindings, quotas and session history.
- `runbooks/<task>.md`: step-by-step procedures done rarely, such as new Mac
  setup and one-time manual grants. Write setup as "set this up again from
  scratch".
- `design/<topic>.md`: how something is built and why, with its decisions.

Rules:

- Keep repository documentation small: setup, everyday usage, required
  maintenance, agent instructions, and concise rationale needed to use or change
  the configuration correctly.
- Docs describe the current state and how to operate it, not a history of
  changes. Remove obsolete instructions, dated status notes and deprecated
  comparisons rather than preserving them as current guidance.
- Put a fact in one place and link to it instead of repeating it.
- Keep agent-only guides focused on agents; put desktop, browser and terminal
  shortcuts in the general keybindings guide.
- When a change affects how a program is used or set up, update its page in
  the same commit.
