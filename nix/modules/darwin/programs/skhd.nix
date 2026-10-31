{
  config,
  lib,
  pkgs,
  repoRoot,
  userName,
  ...
}:
let
  # Keep the bundle identity and signing certificate stable across updates.
  skhdApp = "/Applications/skhd.app";
  skhdBin = "/opt/skhd/bin/skhd";
  label = "org.nixos.skhd";
  homeDir = config.users.users.${userName}.home;
in
{
  nixpkgs.overlays = [
    (final: _prev: {
      skhd = final.callPackage ./skhd-package.nix { };
    })
  ];

  signedBinaries.skhd = {
    source = "${pkgs.skhd}/Applications/skhd.app";
    path = skhdApp;
    identifier = "com.jackielii.skhd";
    executable = "/Contents/MacOS/skhd";
  };

  environment.systemPath = lib.mkBefore [ (builtins.dirOf skhdBin) ];

  # Reads ~/.config/skhd/skhdrc.
  launchd.user.agents.skhd.serviceConfig = {
    # Launch the signed app directly: a shell wrapper can make macOS ask for
    # the shell's Accessibility permission even if it execs into skhd.
    ProgramArguments = [ "${skhdApp}/Contents/MacOS/skhd" ];
    # Bindings run through the shell and call yabai and jq.
    EnvironmentVariables.PATH =
      lib.replaceStrings [ "$HOME" "$USER" ] [ homeDir userName ]
        config.environment.systemPath;
    KeepAlive.PathState.${skhdBin} = true;
    ProcessType = "Interactive";
    # Without its Accessibility grant, skhd exits at once and prompts on every launch.
    ThrottleInterval = 60;
    StandardOutPath = "/tmp/skhd_${userName}.out.log";
    StandardErrorPath = "/tmp/skhd_${userName}.err.log";
  };

  # skhd allows one instance, so remove the agent that `skhd --install-service`
  # created for the Homebrew build before the new agent loads.
  system.activationScripts.extraActivation.text = ''
    /bin/mkdir -p ${builtins.dirOf skhdBin}
    /bin/ln -sfn ${skhdApp}/Contents/MacOS/skhd ${skhdBin}
    skhdUid=$(/usr/bin/id -u ${lib.escapeShellArg userName})
    for oldLabel in com.koekeishiya.skhd com.asmvik.skhd; do
      /bin/launchctl bootout "gui/$skhdUid/$oldLabel" 2>/dev/null || true
      /bin/rm -f "${homeDir}/Library/LaunchAgents/$oldLabel.plist"
    done
  '';

  home-manager.users.${userName} =
    { config, lib, ... }:
    let
      inherit (import ../../home/link-dotfiles.nix { inherit lib config repoRoot; }) linkTree;
    in
    {
      xdg.configFile = linkTree "skhd";

      # skhd's hotloader can reload mid-relink and silently drop bindings from `.load`ed files.
      home.activation.reloadSkhd = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        if [ -x ${skhdBin} ] && /usr/bin/pgrep -x skhd >/dev/null; then
          run ${skhdBin} --reload
        fi
      '';

      programs.zsh.shellAliases = {
        reloadskhd = ''launchctl kickstart -k gui/"$(id -u)"/${label}'';
        reloadall = ''sudo yabai --load-sa ; launchctl kickstart -k gui/"$(id -u)"/org.nixos.yabai ; launchctl kickstart -k gui/"$(id -u)"/${label} ; sketchybar --reload'';
      };
    };
}
