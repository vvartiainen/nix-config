{ pkgs, ... }:
let
  # Lets agents update a PR or issue body from a file without shell command
  # substitution, which permission rules cannot match.
  fjEditBody = pkgs.writeShellApplication {
    name = "fj-edit-body";
    runtimeInputs = [ pkgs.forgejo-cli ];
    text = builtins.readFile ./fj-edit-body.sh;
  };
in
{
  home.packages = [
    pkgs.forgejo-cli
    fjEditBody
  ];
}
