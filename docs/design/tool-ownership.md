# Tool ownership

Each kind of tool has one owner. When two owners provide the same command, use
`type -a <tool>` to see which one wins on `PATH`.

| Owner | Owns |
| --- | --- |
| Nix | System and Home Manager configuration, the common language-server baseline, btop, Neovim nightly with its plugins and parsers, and the repository check tools |
| Homebrew | GUI apps (casks), Mac App Store apps and a set of CLIs, including mise and the default Neovim |
| mise | Language runtimes, project tool versions and uv |
| Mason | Formatter and debugger fallbacks in the default Neovim only |
| Projects | Project-only formatters, debuggers and test runners, or a dev shell that overrides the baseline |

Nix never installs or prunes mise or Mason tools, and removing a declaration
does not uninstall them or their shims. Homebrew removes undeclared packages
but keeps their app data. The manual steps are in
[maintenance](../maintenance.md#updates-and-rollback).
