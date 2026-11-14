{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "flake-update-preview";
      text = ''
        exec ${pkgs.python3}/bin/python3 ${./flake-update-preview.py} ${pkgs.nix}/bin/nix "$@"
      '';
    })
  ];
}
