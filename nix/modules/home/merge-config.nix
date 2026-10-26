# Shell snippet that merges Nix settings into a config file the app also
# writes, and removes settings dropped from Nix. See merge-config.py.
{
  lib,
  pkgs,
  config,
}:
let
  mergeConfig = pkgs.writers.writePython3Bin "merge-config" {
    libraries = [ pkgs.python3Packages.tomli-w ];
  } ./merge-config.py;
in
{
  name,
  path,
  settings,
  format ? "json",
  # JSON to start from when the file does not exist yet.
  initial ? { },
}:
''
  run ${lib.getExe mergeConfig} ${
    lib.escapeShellArgs [
      "--format"
      format
      "--settings"
      ((pkgs.formats.json { }).generate "${name}.json" settings)
      "--state"
      "${config.xdg.stateHome}/nix-config/merged/${name}.json"
      "--initial"
      (builtins.toJSON initial)
      path
    ]
  }
''
