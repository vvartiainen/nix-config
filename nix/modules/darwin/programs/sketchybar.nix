{
  config,
  lib,
  pkgs,
  repoRoot,
  userName,
  ...
}:
let
  homeDir = config.users.users.${userName}.home;
in
{
  # sketchybar allows one instance, so stop the Homebrew service before brew
  # bundle removes the formula and Home Manager starts the new agent.
  system.activationScripts.extraActivation.text = ''
    /bin/launchctl bootout "gui/$(/usr/bin/id -u ${lib.escapeShellArg userName})/homebrew.mxcl.sketchybar" 2>/dev/null || true
    /bin/rm -f "${homeDir}/Library/LaunchAgents/homebrew.mxcl.sketchybar.plist"
  '';

  home-manager.users.${userName} =
    { config, lib, ... }:
    let
      inherit (import ../../home/link-dotfiles.nix { inherit lib config repoRoot; }) linkTree;
    in
    {
      # Runs ~/.config/sketchybar/sketchybarrc from the linked dotfiles.
      programs.sketchybar = {
        enable = true;
        # Plugins parse event payloads with jq.
        extraPackages = [ pkgs.jq ];
      };

      xdg.configFile = linkTree "sketchybar";

      programs.zsh.shellAliases = {
        reloadsketchybar = "sketchybar --reload";
      };
    };
}
