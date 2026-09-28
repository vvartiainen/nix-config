{
  inputs,
  lib,
  pkgs,
  repoRoot,
  userName,
  ...
}:
let
  # true  = Nix-built ImTheSquid fork (/opt/yabai/bin/yabai)
  # false = Homebrew HEAD            (/opt/homebrew/bin/yabai)
  #
  # Activation recreates the service with the selected binary and PATH.
  # yabairc loads the matching scripting addition when the service starts.
  useYabaiFork = true;

  yabaiBin = if useYabaiFork then "/opt/yabai/bin/yabai" else "/opt/homebrew/bin/yabai";
  servicePath = "${builtins.dirOf yabaiBin}:/etc/profiles/per-user/${userName}/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin";
  setupService = pkgs.writeShellScript "setup-yabai-service" ''
    set -eu
    export PATH=${lib.escapeShellArg servicePath}
    # The service label changed upstream. Manage both explicitly because the
    # selected binary's --stop/uninstall-service only handles its own label.
    for label in com.koekeishiya.yabai com.asmvik.yabai; do
      # `print` exits non-zero if the agent isn't loaded in this user's GUI
      # domain; `bootout` stops the process and unloads the agent from launchd.
      if /bin/launchctl print "gui/$(id -u)/$label" >/dev/null 2>&1; then
        /bin/launchctl bootout "gui/$(id -u)/$label"
      fi
      # Remove the plist so --start-service writes a new one with the current
      # binary path and PATH instead of reusing a stale one.
      /bin/rm -f "$HOME/Library/LaunchAgents/$label.plist"
    done
    # Writes ~/Library/LaunchAgents/<label>.plist and bootstraps it into gui/<uid>.
    ${yabaiBin} --start-service
  '';
in
{
  nixpkgs.overlays = lib.optionals useYabaiFork [
    (_final: prev: {
      yabai = prev.yabai.overrideAttrs (old: {
        src = inputs.yabai-src;
        # macOS 27's dyld rejects the scripting addition without LC_UUID.
        postPatch = (old.postPatch or "") + ''
          substituteInPlace makefile --replace-fail '-Wl,-no_uuid' ""
        '';
      });
    })
  ];

  environment.systemPath = lib.mkIf useYabaiFork (lib.mkBefore [ "/opt/yabai/bin" ]);

  # Keep the executable, Dock scripting addition, and launchd service in sync:
  #
  # 1. (Fork only) Install the Nix-built binary to /opt/yabai/bin atomically.
  #    In-place writes caused SIGKILL from stale code signatures.
  # 2. Fail if the selected binary is missing.
  # 3. Write /etc/sudoers.d/yabai so `sudo yabai --load-sa` needs no password,
  #    pinned to the binary's sha256. The file is validated before it's installed.
  # 4. The remaining steps run only if the user is logged into a GUI session:
  #    a. If the binary's hash differs from the one recorded in the installed
  #       scripting addition, reinstall the addition. This restarts Dock.
  #    b. Remove both the old and new launchd agent labels, then recreate the
  #       service with the selected binary and PATH. This restarts yabai.
  #
  # Accessibility approval stays manual.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    yabaiBin="${yabaiBin}"
    sudoersDir="/private/etc/sudoers.d"
    sudoersFile="$sudoersDir/yabai"

    ${lib.optionalString useYabaiFork ''
      mkdir -p "$(dirname "$yabaiBin")"
      # macOS install writes a temp file and renames it over the target, so the
      # new binary gets a fresh inode and the kernel doesn't validate it against
      # the old binary's cached code signature. -C leaves the target alone if it's
      # already identical; -m 755 sets the mode (store files are read-only).
      /usr/bin/install -C -m 755 "${pkgs.yabai}/bin/yabai" "$yabaiBin"
    ''}

    if [[ ! -x "$yabaiBin" ]]; then
      echo "error: yabai binary not found at $yabaiBin" >&2
      exit 1
    fi

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
      # Switch from root to the user (-H sets HOME to the user's home) inside the
      # user's session, so the service is installed in ~/Library/LaunchAgents
      # and loaded into gui/<uid> instead of root's domain.
      /bin/launchctl asuser "$yabaiUid" /usr/bin/sudo -H -u ${lib.escapeShellArg userName} ${setupService}
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
        reloadyabai = "sudo yabai --load-sa && yabai --restart-service";
      };
    };
}
