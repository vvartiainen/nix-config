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

  home = {
    # Editor tooling comes from Nix so it matches the Go toolchain above.
    packages = with pkgs; [
      delve
      golangci-lint
      gopls
    ];
    sessionPath = [ goBin ];
    sessionVariables.GOPATH = goPath;
  };
}
