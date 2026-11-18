# nix-config

Declarative macOS configuration using Nix, nix-darwin and Home Manager.

## Working in this repo

- Keep program modules independently importable under
  `nix/modules/home/programs/` or `nix/modules/darwin/programs/`. Use host
  files for composition and host facts.
- Update `flake.lock` for intentional input changes. Keep real host identity,
  private modules and credentials outside this repository.
- Update the relevant page in `docs/programs/` or `docs/agents/` when setup
  or usage changes. Use `docs/design/` for rationale and `docs/runbooks/`
  for infrequent procedures.

## Validation commands (no apply)

- Documentation-only changes: review the diff and run `git diff --check`.
- Run `just lint` for changed files and `just lint --tests` for code changes.
  Use `just lint --base <revision>` to include committed changes. Formatting
  checks are opt-in with `--format`. The agent Stop hooks run the fast
  checks, with fast tests for code changes. See
  [maintenance](docs/maintenance.md#repository-checks) for larger suites.
- For directly linked dotfiles and scripts, run targeted syntax or behavior
  checks. For Nix module changes, stage new files and run `just check-fixture`
  (Statix and system derivation evaluation). For changes to packages,
  dependencies, activation or build behavior, also run `just build-fixture`.
- Both fixture recipes use synthetic host data.
  For direct system evaluation or builds, use the
  [tracked host fixture](nix/fixtures/host/default.nix) with
  `--override-input host "path:$PWD/nix/fixtures/host"`. Leave private host
  validation, initialization and system applies to the user.
- Follow [agent permissions](docs/agents/permissions.md) for the active
  session. If the Nix daemon is unavailable, run the checks that work without
  it and report the fixture steps that remain. Use the normal approval flow
  for host runtime tests and keep test credentials and sockets synthetic.

## Changes and reviews

- Use Forgejo for issues and search for existing work before opening an issue.
- Branch from current `main` and commit only task changes with a short
  Conventional Commit subject and no trailers. Push to Forgejo (`origin`)
  and open a PR against `main` using the
  [PR template](.forgejo/pull_request_template.md). The user handles pushes
  to the public GitHub mirror.
- For multi-remote checkouts, use the
  [Forgejo repository discovery guidance](docs/agents/permissions.md#forgejo-repository-discovery).
  Link the PR to its T3 thread when working in T3.
