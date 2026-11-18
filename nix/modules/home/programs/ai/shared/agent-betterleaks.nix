{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "agent-betterleaks";
      runtimeInputs = [
        pkgs.betterleaks
        pkgs.coreutils
      ];
      text = builtins.readFile ./agent-betterleaks.sh;
    })
  ];
}
