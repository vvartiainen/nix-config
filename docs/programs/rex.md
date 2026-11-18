# Rex

The Rex GUI app runs the server; this flake supplies the CLI and terminfo.
Keybindings are in [keybindings](../keybindings.md#rex).

## Reload

Run `rex config reload` (or `reloadall`) for Lua changes. Quit Rex before
applying GUI preference changes, then reopen it.

## Theme

Select **Apply Catppuccin Mocha** in Rex's palette once per Mac and after
palette changes.

## Remote access

Run `rex terminfo setup` once for the SSH fallback. Each agent host needs its
own Rex server, added separately in the Mac app, iPhone and CLI. Keep pairing
details private, and check access from the phone on cellular.

## Update

`just up rex` moves the CLI to the newest preview. Bump the pinned GUI build in
`nix/modules/darwin/programs/rex.nix` in the same change; both share an API
revision.
