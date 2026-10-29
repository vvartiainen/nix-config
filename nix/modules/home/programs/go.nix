{ config, ... }:
let
  goPath = "${config.home.homeDirectory}/golang";
  goBin = "${goPath}/bin";
in
{
  programs.go = {
    enable = true;
    telemetry.mode = "off";
    env = {
      GOPATH = goPath;
      GOBIN = goBin;
    };
  };

  home.sessionPath = [ goBin ];
  home.sessionVariables.GOPATH = goPath;
}
