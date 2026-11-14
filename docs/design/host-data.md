# Host data

The public flake holds no machine identity. Each Mac keeps its user name, host
name, repository path, hardware facts and private modules outside the repo in
`~/.config/nix-config-host/`, which becomes the flake's `host` input. The
repository stays publishable and work-specific configuration stays private.
Never commit real hostnames, usernames, or work-specific configuration.

## The host file

`~/.config/nix-config-host/default.nix`:

```nix
{
  userName = "your-user";
  hostName = "YOUR-HOSTNAME"; # also the darwinConfigurations name
  repoRoot = "/Users/your-user/prog/nix-config";
  nestedVirtualization = true; # M3+ and macOS 15+; false on older Macs
  darwinModules = [ ];
  homeModules = [
    ./zen-work.nix # optional private module; remove if unused
    {
      # SFTP hosts for yazi (`yy sftp://my-server`); auth via SSH_AUTH_SOCK.
      programs.yazi.vfs.sftp.my-server = {
        host = "203.0.113.10";
        user = "me";
        port = 22;
      };
    }
  ];
}
```

`just init-host <HOSTNAME>` generates it from the current user, hostname, chip
and repository path; `just bootstrap` creates it if it is missing.

## How it is passed in

The flake's `host` input defaults to a stub that fails with an error. The `just`
recipes select the real directory with
`--override-input host "path:$HOME/.config/nix-config-host"`. This implies
`--no-write-lock-file`, so the path never ends up in `flake.lock`. Use the same
flag with raw `nix` or `darwin-rebuild` commands for your machine.

Only that directory and tracked repository files are copied into the Nix store.
New repository files need `git add` before a build sees them.

Use `hostName` for `<HOSTNAME>` in recipes; it defaults to `hostname` (or `HOST`
if exported). Recipes stop with a hint when host data is missing.

## Public fixture

`nix/fixtures/host` holds synthetic host data for agent evaluation and builds:
synthetic identity and paths, nested virtualization disabled and no private
modules. Agents validate with it instead of reading private host data, so their
checks cover public configuration only. Never activate it. The commands are in
[AGENTS.md](../../AGENTS.md#validation-commands-no-apply).
