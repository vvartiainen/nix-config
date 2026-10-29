{ config, pkgs, ... }:
let
  goPath = "${config.home.homeDirectory}/golang";
  goBin = "${goPath}/bin";
in
{
  programs.go = {
    enable = true;
    package = pkgs.go_1_27;
    telemetry.mode = "off";
    env = {
      GOPATH = goPath;
      GOBIN = goBin;
    };
  };

  home.sessionPath = [ goBin ];
  home.sessionVariables.GOPATH = goPath;
}
