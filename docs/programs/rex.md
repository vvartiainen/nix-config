# Rex

The Rex GUI app runs the macOS server; this flake supplies the CLI and
terminfo. Keybindings are in [keybindings](../keybindings.md#rex).

## Reload

Reload Lua configuration with `rex config reload`; `reloadall` also does it.
GUI preference changes need an app restart: quit Rex before applying them,
then reopen it.

## Theme

Select **Apply Catppuccin Mocha** in Rex's palette once per Mac and again after
changing the palette; reloading Lua alone does not select it.

## Remote access

Run `rex terminfo setup` once for the SSH fallback. Each agent host needs its
own Rex server. Add each host separately in the Mac app, iPhone and CLI; the
Mac is not a proxy for Linux sessions. Keep enrollment state and pairing
addresses private. Check access after a server restart and from the phone on
cellular before relying on it.

## Update

The flake tracks Rex's preview channel, so `just up rex` moves the CLI to the
newest preview. The GUI build in `nix/modules/darwin/programs/rex.nix` is
pinned by hand; bump it in the same change, because the CLI and app share an
API revision.
