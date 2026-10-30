{
  config,
  inputs,
  lib,
  pkgs,
  repoRoot,
  userName,
  ...
}:
let
  # Signed copy outside the store, so Accessibility approval survives yabai
  # updates and the sudoers rule has a fixed binary to pin.
  yabaiBin = "/opt/yabai/bin/yabai";
  servicePath = "${builtins.dirOf yabaiBin}:/etc/profiles/per-user/${userName}/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin";
  label = "org.nixos.yabai";
  homeDir = config.users.users.${userName}.home;
in
{
  nixpkgs.overlays = [
    (_final: prev: {
      yabai = prev.yabai.overrideAttrs (old: {
        # Read the version from the fork so versionCheckHook matches it.
        version =
          let
            source = builtins.readFile "${inputs.yabai-src}/src/yabai.c";
            part = name: builtins.head (builtins.match ".*#define ${name} +([0-9]+).*" source);
          in
          "${part "MAJOR"}.${part "MINOR"}.${part "PATCH"}";
        src = inputs.yabai-src;
        meta = old.meta // {
          homepage = "https://github.com/Christian-SC26/yabai";
        };
      });
    })
  ];

  signedBinaries.yabai = {
    source = "${pkgs.yabai}/bin/yabai";
    path = yabaiBin;
    # postActivation restarts yabai after reloading the scripting addition.
    restart = false;
  };

  environment.systemPath = lib.mkBefore [ (builtins.dirOf yabaiBin) ];

  # Reads ~/.config/yabai/yabairc. The scripting addition is managed by the
  # activation script below, not by enableScriptingAddition, so the sudoers
  # rule pins the stable binary instead of the store path.
  services.yabai = {
    enable = true;
    package = pkgs.yabai;
  };

  launchd.user.agents.yabai.serviceConfig = {
    # yabai unlinks a stale socket itself, and its fcntl lock dies with the
    # process, so no cleanup is needed before starting.
    ProgramArguments = lib.mkForce [ yabaiBin ];
    # yabairc resolves `yabai` through PATH; keep the stable binary first so
    # `sudo yabai --load-sa` matches the sudoers rule.
    EnvironmentVariables.PATH = lib.mkForce servicePath;
    KeepAlive = lib.mkForce {
      PathState.${yabaiBin} = true;
    };
    # Without its Accessibility grant, yabai exits at once and prompts on every launch.
    ThrottleInterval = 60;
    StandardOutPath = "/tmp/yabai_${userName}.out.log";
    StandardErrorPath = "/tmp/yabai_${userName}.err.log";
  };

  # signed-binaries.nix installs the signed binary to /opt/yabai/bin earlier in
  # activation. Keep the Dock scripting addition and launchd service in sync:
  #
  # 1. Write /etc/sudoers.d/yabai so `sudo yabai --load-sa` needs no password,
  #    pinned to the binary's sha256. The file is validated before it's installed.
  # 2. The remaining steps run only if the user is logged into a GUI session:
  #    a. If the binary's hash differs from the one recorded in the installed
  #       scripting addition, reinstall the addition. This restarts Dock.
  #    b. Remove the agents that `yabai --start-service` used to install.
  #    c. Stop the nix-darwin agent so KeepAlive restarts it. Its plist doesn't
  #       change when only the binary does, so launchd wouldn't restart it otherwise.
  #
  # Accessibility approval stays manual, once per signing key.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    yabaiBin="${yabaiBin}"
    sudoersDir="/private/etc/sudoers.d"
    sudoersFile="$sudoersDir/yabai"

    yabaiHash=$(shasum -a 256 "$yabaiBin" | cut -d " " -f 1)
    mkdir -p "$sudoersDir"
    # Create the temp file in sudoers.d itself so the final `mv` is a rename on
    # the same filesystem. sudo ignores names containing a dot, so it never
    # reads the partly written temp file. The trap removes it if a later step fails.
    sudoersTemp=$(mktemp "$sudoersDir/.yabai.XXXXXX")
    trap 'rm -f "$sudoersTemp"' EXIT

    # `sha256:<digest>` makes sudo allow the command only if the binary's hash
    # still matches, so replacing the binary makes the rule stop working until
    # the next activation rewrites it.
    printf '%s ALL=(root) NOPASSWD: sha256:%s %s --load-sa\n' \
      "${userName}" "$yabaiHash" "$yabaiBin" > "$sudoersTemp"
    # sudo refuses sudoers files that aren't root-owned or are writable by others.
    chmod 0440 "$sudoersTemp"
    chown root:wheel "$sudoersTemp"
    # -c checks syntax only and -f selects the file. A syntax error aborts here,
    # before the file is installed; a broken sudoers file could lock out sudo.
    /usr/sbin/visudo -cf "$sudoersTemp" > /dev/null
    mv -f "$sudoersTemp" "$sudoersFile"

    trap - EXIT

    # Run in the user's GUI session, after installing the binary and sudo rule.
    # The gui/<uid> launchd domain exists only while the user is logged in at
    # the console, so this is skipped during boot-time or SSH-only activations.
    yabaiUid=$(/usr/bin/id -u ${lib.escapeShellArg userName})
    if /bin/launchctl print "gui/$yabaiUid" >/dev/null 2>&1; then
      # Forks can share OSAX_VERSION with upstream, so --load-sa alone may
      # reuse an incompatible payload. Track the binary that installed it.
      saHashFile=/Library/ScriptingAdditions/yabai.osax/Contents/nix-binary-sha256
      if [[ ! -f "$saHashFile" ]] || [[ "$(cat "$saHashFile")" != "$yabaiHash" ]]; then
        # Deletes /Library/ScriptingAdditions/yabai.osax so --load-sa has to
        # reinstall it instead of treating it as up to date.
        "$yabaiBin" --uninstall-sa
        # `asuser` runs the command, still as root, inside the user's per-login
        # bootstrap namespace. --load-sa needs root to write under /Library, and
        # it needs the user's session to find the Dock process and inject into it.
        /bin/launchctl asuser "$yabaiUid" "$yabaiBin" --load-sa
        printf '%s\n' "$yabaiHash" > "$saHashFile"
      fi

      # A second instance would hold the lock and keep this agent from starting.
      for oldLabel in com.koekeishiya.yabai com.asmvik.yabai; do
        if /bin/launchctl print "gui/$yabaiUid/$oldLabel" >/dev/null 2>&1; then
          /bin/launchctl bootout "gui/$yabaiUid/$oldLabel"
        fi
        /bin/rm -f "${homeDir}/Library/LaunchAgents/$oldLabel.plist"
      done

      # Stop a running instance and let KeepAlive start the new binary.
      # `kickstart -k` would block activation while yabai can't start, for
      # example before its Accessibility approval.
      /bin/launchctl kill SIGTERM "gui/$yabaiUid/${label}" 2>/dev/null || true
    fi
  '';

  home-manager.users.${userName} =
    { config, lib, ... }:
    let
      inherit (import ../../home/link-dotfiles.nix { inherit lib config repoRoot; }) linkTree;
    in
    {
      xdg.configFile = linkTree "yabai";

      programs.zsh.shellAliases = {
        reloadyabai = ''sudo yabai --load-sa && launchctl kickstart -k gui/"$(id -u)"/${label}'';
      };
    };
}
