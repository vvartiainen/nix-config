{ pkgs }:
pkgs.writeShellApplication {
  name = "nix-config-check";
  runtimeInputs = with pkgs; [
    bash
    deadnix
    git
    nixfmt
    python3
    ruff
    shellcheck
    shfmt
    statix
    stylua
    zsh
  ];
  text = ''
    exec python3 ${../../scripts/check-repository.py} "$@"
  '';
}
