# Host data

The public flake holds no machine identity. Each Mac keeps its user name, host
name, repository path, hardware facts and private modules outside the repo in
`~/.config/nix-config-host/`, which becomes the flake's `host` input, so the
repository stays publishable. Never commit real hostnames, usernames or
work-specific configuration.

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

The `host` input defaults to a stub that fails. The `just` recipes pass the
real directory; use the same flag with raw `nix` or `darwin-rebuild`:

```sh
--override-input host "path:$HOME/.config/nix-config-host"
```

It implies `--no-write-lock-file`, so the path never enters `flake.lock`. New
repository files need `git add` before a build sees them. `<HOSTNAME>` in
recipes is `hostName` and defaults to `hostname` (or `HOST`).

## Public fixture

`nix/fixtures/host` holds synthetic host data for agent evaluation and builds,
covering public configuration only. Never activate it. The commands are in
[AGENTS.md](../../AGENTS.md#validation-commands-no-apply).
