{ pkgs, lib, ... }:
let
  configSrc = ../../../../dotfiles/nvim;
  # Lazy and LazyVim update these at runtime. Keep their experimental copies
  # writable, while all Lua configuration comes from the Nix store.
  mutableFiles = [
    "lazy-lock.json"
    "lazyvim.json"
  ];
  configSnapshot = lib.cleanSourceWith {
    src = configSrc;
    filter = path: _type: !(builtins.elem (builtins.baseNameOf path) mutableFiles);
  };
  neovim = pkgs.writeShellApplication {
    name = "nvim-nix";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      export NVIM_APPNAME=nvim-nix
      configDir="''${XDG_CONFIG_HOME:-$HOME/.config}/$NVIM_APPNAME"
      mkdir -p "$configDir"
      for file in ${lib.escapeShellArgs mutableFiles}; do
        if [ ! -e "$configDir/$file" ]; then
          cp ${configSrc}/"$file" "$configDir/$file"
          chmod u+w "$configDir/$file"
        fi
      done
      exec ${lib.getExe pkgs.neovim} "$@"
    '';
  };
in
{
  # Do not expose another `nvim` binary or change EDITOR during migration.
  home.packages = [ neovim ];
  xdg.configFile."nvim-nix" = {
    source = configSnapshot;
    recursive = true;
  };
}
