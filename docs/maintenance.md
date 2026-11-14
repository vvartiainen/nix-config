# Maintenance and validation

## Validate and apply

The user validates private host configuration and applies it manually:

```sh
just check <HOSTNAME>      # lint, evaluate, validate installed agent config
just build <HOSTNAME>      # build and compare packages with the active system
just switch <HOSTNAME>     # apply
just switch <HOSTNAME> 1   # apply without Homebrew bundle
```

See [host data](runbooks/new-mac.md#host-data) for host selection and
[agent configuration validation](agents/config.md#configuration-validation)
for coverage. The package diff includes all pending Nix changes; it excludes
Homebrew and mise updates. After applying, reload the
[desktop](programs/desktop.md#reload-after-changes),
[terminal](programs/terminal.md#reload-changes) and
[Rex](programs/rex.md#reload) as needed.

## Repository checks

```sh
just lint                      # staged, unstaged and untracked files
just lint --base HEAD~1         # also include changes in the last commit
just lint --all                 # audit all owned files
just lint --format              # also check formatting without writing files
```

Checks use ShellCheck and shell syntax checks, Statix, Deadnix, Ruff and
`git diff --check`. Zsh uses `zsh -n` instead of ShellCheck. ShellCheck skips
runtime-resolved sources; their files are checked separately. Formatting checks
use Ruff, nixfmt, shfmt and StyLua, respecting Neovim's existing StyLua config.
Formatting is opt-in while existing files have mixed styles. Vendored Yazi
plugins/flavors and symlinks are excluded. Missing tools fail the check;
apply the configuration manually to install the tool set and `nix-config-check`,
which runs the same checker with its Nix-provided tools.

After applying, start fresh Codex, Claude and Copilot sessions to load the
repository validation hooks; approve them in the agent UI if requested.
They run the fast checks before the agent finishes, including commits made
since the current prompt. Agent validation, hook scope and failure handling
are defined in [AGENTS.md](../AGENTS.md#validation-commands-no-apply); agents
never use private host data or apply a system configuration.

## Updates and rollback

```sh
just up <INPUT>...             # selected inputs; omit names to update all
just generations
just rollback                  # previous system and Home Manager generation
just rollback-to <GENERATION>
just clean                     # remove generations older than 7 days and GC
```

Review `flake.lock` and `just build` before switching. The main `nixpkgs` input
tracks unstable. Some inputs have their own update steps:
[Rosetta image](programs/linux-builders.md#update-the-rosetta-image),
[Neovim nightly](programs/neovim.md#change-or-update-nightly) and
[Rex](programs/rex.md#update).
Weekly GC removes old system generations; `just clean` also handles user
Home Manager generations. Garbage-collected generations cannot be restored.

Nix activation prints a reminder when managed mise inputs change; it does not
install or prune tools. Run installation manually from the home context:

```sh
mise -C ~ install
mise prune --dry-run
```

Review the preview before running `mise prune`: projects may still need those
versions. Nix owns common language servers and btop; mise owns runtimes and uv.
Use `type -a <tool>` to diagnose competing installations.

## Homebrew app data

Activation uses `homebrew.onActivation.cleanup = "uninstall"`: undeclared
Homebrew packages are removed, while cask preferences and app data are kept
for rollback. Review and delete that data manually after accepting a removal.
To remove saved data for a removed cask, replace `CASK_NAME` below:

```sh
brew uninstall --cask --zap --force CASK_NAME
```

`--force` allows zapping an already uninstalled cask. Zap removes the files
listed by the cask, which can include shared files; back up anything needed
first. See [Homebrew's uninstall options](https://docs.brew.sh/Manpage#uninstall-remove-rm-options-installed_formulainstalled_cask-).
`brew cleanup` removes old downloads and package versions, not saved app data.

## Backups and Spotlight

Time Machine excludes the Nix store, VM disks and rebuildable tool caches.
Check with `tmutil isexcluded /nix`. Treat VM disks as rebuildable; keep
important data elsewhere. Agent sessions are archived separately; see
[session history](agents/sessions.md#session-history).

Activation disables Spotlight indexing on a separately mounted `/nix` only when
`mdutil -s /nix` reports `Indexing enabled.` Standard Nix volumes may instead
report `unknown indexing state` (-400); activation skips these, without claiming
an exclusion was applied. Time Machine exclusions do not affect Spotlight.
Folder exclusions for rebuildable caches must be added in System Settings →
Spotlight → Search Privacy; `mdutil` controls entire volumes.
