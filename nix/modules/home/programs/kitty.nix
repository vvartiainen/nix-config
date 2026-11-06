{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Explicit extensions override apps such as Xcode that claim specific text
  # types. Avoid public.data or public.content, which would also claim binaries.
  editorExtensions = [
    "md"
    "markdown"
    "txt"
    "log"
    "json"
    "jsonc"
    "yaml"
    "yml"
    "toml"
    "ini"
    "conf"
    "cfg"
    "nix"
    "lua"
    "sh"
    "bash"
    "zsh"
    "fish"
    "py"
    "rb"
    "rs"
    "go"
    "js"
    "jsx"
    "ts"
    "tsx"
    "css"
    "scss"
    "html"
    "xml"
    "sql"
    "c"
    "h"
    "cpp"
    "hpp"
    "swift"
  ];
  fileAssociations =
    lib.concatMapStringsSep "\n"
      (type: "run ${lib.getExe pkgs.duti} -s net.kovidgoyal.kitty ${lib.escapeShellArg type} all")
      (
        [
          "public.plain-text"
          "public.source-code"
          "public.folder"
        ]
        ++ map (extension: ".${extension}") editorExtensions
      );
in
{
  home = {
    packages = [ pkgs.duti ];

    activation = {
      # Use Launch Services rather than replacing its preference array. Each
      # command reports failures; duti's settings-file mode discards them.
      # Homebrew installs Kitty before Home Manager; dry runs do not apply.
      kittyFileAssociations = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [[ -d /Applications/kitty.app ]]; then
          ${fileAssociations}
        else
          echo >&2 "Kitty is not installed; skipping its file associations."
        fi
      '';

      # Protect the remote-control sockets from other local users. Kitty does not
      # create the parent directory itself.
      kittySocketDirectory = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${pkgs.coreutils}/bin/install -d -m 700 ${lib.escapeShellArg "${config.home.homeDirectory}/.local/state/kitty"}
      '';
    };
  };

  # kitten ssh brings kitty shell integration to the remote: edit-in-kitty,
  # hyperlinked remote files and kitten transfer. Only in kitty itself; tmux
  # and other terminals keep plain ssh.
  programs.zsh.initContent = ''
    # Kitty injects integration only into its initial shell. Load it again
    # after `exec zsh`; _ksi_state prevents duplicate hooks in the first shell.
    if [[ $TERM == xterm-kitty && -n $KITTY_INSTALLATION_DIR &&
          -r $KITTY_INSTALLATION_DIR/shell-integration/zsh/kitty-integration ]] &&
       (( ! $+_ksi_state )); then
      export KITTY_SHELL_INTEGRATION=enabled
      autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
      kitty-integration
      unfunction kitty-integration
    fi

    [[ $TERM == xterm-kitty ]] && alias ssh='kitten ssh'
  '';
}
