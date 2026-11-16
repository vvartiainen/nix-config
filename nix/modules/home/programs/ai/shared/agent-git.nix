{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "agent-git";
      text = ''
        exec ${pkgs.python3}/bin/python3 -I ${./agent-git.py} ${pkgs.git}/bin/git "$@"
      '';
    })
  ];
}
