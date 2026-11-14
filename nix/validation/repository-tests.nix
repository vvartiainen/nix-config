{ pkgs, darwin }:
let
  validation = import ./agent-config-validation.nix { inherit pkgs; };
  python = pkgs.python3.withPackages (ps: [ validation ps.tomli-w ps.tomlkit ]);
  fixture = import ../../tests/ai/permission-fixture.nix darwin;
  policy = pkgs.writeText "repository-permission-fixture.json" (builtins.toJSON fixture);
  checker = import ./repository-checks.nix { inherit pkgs; };
in
pkgs.writeShellApplication {
  name = "nix-config-test";
  runtimeInputs = [ python ] ++ checker.tools;
  text = ''
    export AI_PERMISSION_FIXTURE=${policy}
    export SAFEHOUSE=${pkgs.lib.getExe pkgs.agent-safehouse}
    exec ${python}/bin/python3 -B nix/validation/test-repository.py "$@"
  '';
}
