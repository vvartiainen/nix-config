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
  # Switching versions:
  #   1. yabai --stop-service
  #   2. yabai --uninstall-service
  #   3. sudo yabai --uninstall-sa
  #   4. Flip useYabaiFork
  #   5. just switch
  #   6. Open a new shell so PATH picks up the other binary
  #   7. yabai --start-service
  #   8. sudo yabai --load-sa
  #
  # The launchd plist records the absolute binary path, and --load-sa
  # installs the scripting-addition from whatever yabai is now on PATH.
  useYabaiFork = true;

  yabaiBin = if useYabaiFork then "/opt/yabai/bin/yabai" else "/opt/homebrew/bin/yabai";
in
{
  nixpkgs.overlays = lib.optionals useYabaiFork [
    (final: prev: {
      yabai = prev.yabai.overrideAttrs {
        src = inputs.yabai-src;
      };
    })
  ];

  environment.systemPath = lib.mkIf useYabaiFork (lib.mkBefore [ "/opt/yabai/bin" ]);

  system.activationScripts.postActivation.text = lib.mkAfter ''
    yabaiBin="${yabaiBin}"
    sudoersDir="/private/etc/sudoers.d"
    sudoersFile="$sudoersDir/yabai"

    ${lib.optionalString useYabaiFork ''
      mkdir -p "$(dirname "$yabaiBin")"
      cp -f "${pkgs.yabai}/bin/yabai" "$yabaiBin"
      chmod 755 "$yabaiBin"
      codesign -fs 'yabai-cert' "$yabaiBin"
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
