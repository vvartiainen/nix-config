{
  lib,
  pkgs,
  userName,
  ...
}:
let
  # Neovim is a terminal program: macOS opens its host app, whose launch rules
  # start the editor. Change the app here to change defaults across macOS.
  editor = "net.kovidgoyal.kitty";
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
    "xml"
    "sql"
    "c"
    "h"
    "cpp"
    "hpp"
    "swift"
  ];
  # Specific handlers take precedence over generic source-code/plain-text
  # defaults. Include the source and script types claimed by Xcode explicitly.
  editorTypes = [
    "public.plain-text"
    "public.source-code"
    "public.script"
    "public.swift-source"
    "public.c-header"
    "public.c-plus-plus-header"
    "public.c-source"
    "public.c-plus-plus-source"
    "public.objective-c-source"
    "public.objective-c-plus-plus-source"
    "public.opencl-source"
    "public.module-map"
    "public.assembly-source"
    "public.nasm-assembly-source"
    "public.mig-source"
    "public.make-source"
    "public.ruby-script"
    "public.python-script"
    "public.perl-script"
    "public.php-script"
    "public.shell-script"
    "public.bash-script"
    "public.csh-script"
    "public.ksh-script"
    "public.tcsh-script"
    "public.zsh-script"
    "public.xml"
    "public.json"
    "public.yaml"
  ]
  ++ map (extension: ".${extension}") editorExtensions;
  defaultApplications = lib.genAttrs editorTypes (_: editor) // {
    # Explicitly restore Finder if an earlier configuration selected Kitty.
    "public.folder" = "com.apple.finder";
  };
  setDefaultApplication = pkgs.writeShellScript "set-default-application" (
    builtins.readFile ./set-default-application.sh
  );
in
{
  # Launch Services defaults are per user, even when managed by nix-darwin.
  home-manager.users.${userName} = { lib, ... }: {
    home = {
      packages = [ pkgs.duti ];
      # Use Launch Services rather than replacing its preference array. Individual
      # commands propagate failures, except rejected dynamic extension types.
      # Homebrew installs the apps before Home Manager; dry runs do not apply.
      activation.defaultApplications = lib.hm.dag.entryAfter [ "writeBoundary" ] (
        lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            type: app:
            "run ${setDefaultApplication} ${lib.getExe pkgs.duti} ${
              lib.escapeShellArgs [
                app
                type
              ]
            }"
          ) defaultApplications
        )
      );
    };
  };
}
