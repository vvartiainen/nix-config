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
    ct = "cli-toolbox";
    fssh = "cli-toolbox ssh connect";
    faws = "eval \"$(cli-toolbox aws profile)\"";
    fkittysession = "cli-toolbox kitty select-session";
  };
}
