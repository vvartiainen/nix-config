{ config, ... }:
let
  goPath = "${config.home.homeDirectory}/golang";
  goBin = "${goPath}/bin";
in
{
  programs.go = {
    enable = true;
    env = {
      GOPATH = goPath;
      GOBIN = goBin;
    };
  };

  home.sessionPath = [ goBin ];
  home.sessionVariables.GOPATH = goPath;
}
