# direnv

direnv with nix-direnv loads a project's flake devShell into the current zsh
when you `cd` into it and unloads it when you leave, instead of starting the
bash subshell of `nix develop`.

## Use a devShell

In a project with a flake that defines a devShell:

```sh
echo "use flake" > .envrc
direnv allow
```

Run `direnv allow` again after editing `.envrc`; direnv blocks a changed file
until then. nix-direnv caches the environment in `.direnv/` and roots it
against garbage collection; the global git ignore list excludes it.

Bash functions and aliases from a devShell's `shellHook` do not carry over;
exported variables and `PATH` do.

## Reload

The cache updates when `flake.nix`, `flake.lock` or `.envrc` changes. Force a
reload with `direnv reload`; remove `.direnv/` to drop the cached environment.
