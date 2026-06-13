{
  pkgs,
  inputs,
  ...
}:
{
  home.packages = [
    inputs.cli-toolbox.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  programs.zsh.shellAliases = {
    fssh = "cli-toolbox ssh";
    faws = "cli-toolbox aws profile";
    fkittysession = "cli-toolbox kitty-session";
  };
}
