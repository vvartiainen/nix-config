{ pkgs }:
let
  tools = with pkgs; [
    bash
    deadnix
    git
    luajit
    nixfmt
    nodejs
    python3
    ruff
    shellcheck
    shfmt
    statix
    stylua
    yamllint
    zsh
  ];
in
pkgs.writeShellApplication {
  name = "nix-config-check";
  runtimeInputs = tools;
  derivationArgs.passthru = { inherit tools; };
  text = ''
    exec python3 ${./check-repository.py} "$@"
  '';
}
