# Shell snippet that merges Nix settings into a config file the app also
# writes, and removes settings dropped from Nix. See merge-config.py.
{
  lib,
  pkgs,
  config,
}:
let
  mergeConfig = pkgs.writers.writePython3Bin "merge-config" {
    libraries = [
      pkgs.python3Packages.tomli-w
      (import ./agent-config-validation.nix { inherit pkgs; })
    ];
  } ./merge-config.py;
  python = pkgs.python3.withPackages (_: [
    (import ./agent-config-validation.nix { inherit pkgs; })
  ]);
in
{
  name,
  path,
  settings,
  format ? "json",
  # JSON to start from when the file does not exist yet.
  initial ? { },
  schema ? null,
}:
let
  generated = (pkgs.formats.json { }).generate "${name}.json" settings;
  checked =
    if schema == null then
      generated
    else
      pkgs.runCommandLocal "${name}-validated.json" { } ''
        ${python}/bin/python3 -c 'from agent_config_validation import load, validate; import sys; validate(load(sys.argv[1]), sys.argv[2], sys.argv[1])' \
          ${generated} ${lib.escapeShellArg schema}
        cp ${generated} "$out"
      '';
in
''
  run ${lib.getExe mergeConfig} ${
    lib.escapeShellArgs (
      [
        "--format"
        format
        "--settings"
        checked
        "--state"
        "${config.xdg.stateHome}/nix-config/merged/${name}.json"
        "--initial"
        (builtins.toJSON initial)
        path
      ]
      ++ lib.optionals (schema != null) [
        "--schema"
        schema
      ]
    )
  }
''
