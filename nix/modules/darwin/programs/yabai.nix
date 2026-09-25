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
      if /bin/launchctl print "gui/$(id -u)/$label" >/dev/null 2>&1; then
        /bin/launchctl bootout "gui/$(id -u)/$label"
      fi
      /bin/rm -f "$HOME/Library/LaunchAgents/$label.plist"
    done
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

  # Keep the executable, Dock scripting addition, and launchd service in sync.
  # Install the fork atomically (in-place writes caused SIGKILL from stale code
  # signatures), then authorize its hash for passwordless --load-sa. With a GUI
  # session, refresh the addition only when that hash changes, and recreate the
  # service with the selected binary/PATH. Refreshing the addition restarts Dock;
  # recreating the service restarts yabai. Accessibility approval stays manual.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    yabaiBin="${yabaiBin}"
    sudoersDir="/private/etc/sudoers.d"
    sudoersFile="$sudoersDir/yabai"

    ${lib.optionalString useYabaiFork ''
      mkdir -p "$(dirname "$yabaiBin")"
      # macOS install replaces files atomically; -C leaves identical files alone.
      /usr/bin/install -C -m 755 "${pkgs.yabai}/bin/yabai" "$yabaiBin"
    ''}

    if [[ ! -x "$yabaiBin" ]]; then
      echo "error: yabai binary not found at $yabaiBin" >&2
      exit 1
    fi

    yabaiHash=$(shasum -a 256 "$yabaiBin" | cut -d " " -f 1)
    mkdir -p "$sudoersDir"
    sudoersTemp=$(mktemp "$sudoersDir/.yabai.XXXXXX")
    trap 'rm -f "$sudoersTemp"' EXIT

    printf '%s ALL=(root) NOPASSWD: sha256:%s %s --load-sa\n' \
      "${userName}" "$yabaiHash" "$yabaiBin" > "$sudoersTemp"
    chmod 0440 "$sudoersTemp"
    chown root:wheel "$sudoersTemp"
    /usr/sbin/visudo -cf "$sudoersTemp" > /dev/null
    mv -f "$sudoersTemp" "$sudoersFile"

    trap - EXIT

    # Run in the user's GUI session, after installing the binary and sudo rule.
    yabaiUid=$(/usr/bin/id -u ${lib.escapeShellArg userName})
    if /bin/launchctl print "gui/$yabaiUid" >/dev/null 2>&1; then
      # Forks can share OSAX_VERSION with upstream, so --load-sa alone may
      # reuse an incompatible payload. Track the binary that installed it.
      saHashFile=/Library/ScriptingAdditions/yabai.osax/Contents/nix-binary-sha256
      if [[ ! -f "$saHashFile" ]] || [[ "$(cat "$saHashFile")" != "$yabaiHash" ]]; then
        "$yabaiBin" --uninstall-sa
        /bin/launchctl asuser "$yabaiUid" "$yabaiBin" --load-sa
        printf '%s\n' "$yabaiHash" > "$saHashFile"
      fi
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
