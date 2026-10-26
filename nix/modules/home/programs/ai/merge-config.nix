# Merge Nix settings into a config file that the app also writes. The last
# applied settings are kept in the Home Manager state dir, so keys removed from
# Nix are also removed from the file on the next activation, like
# `kubectl apply`. Keys added by the app are kept. Arrays are replaced whole.
{
  lib,
  pkgs,
  config,
}:
{
  name,
  path,
  settings,
  format ? "json",
}:
let
  jq = lib.getExe pkgs.jq;
  yq = lib.getExe pkgs.yq-go;
  static = (pkgs.formats.json { }).generate "${name}.json" settings;
  state = "${config.xdg.stateHome}/nix-config/merged/${name}.json";
  read = if format == "toml" then "${yq} -p toml -o json" else "${jq} '.'";
  write = if format == "toml" then "${yq} -p json -o toml" else "${jq} -S '.'";
  filter = ''
    def prune($old; $new):
      if type == "object" and ($old | type) == "object" then
        reduce ($old | keys[]) as $k (.;
          if ($new | type) == "object" and ($new | has($k)) then
            if has($k) then .[$k] |= prune($old[$k]; $new[$k]) else . end
          else
            del(.[$k])
          end)
      else
        .
      end;
    if type == "object" then prune($old[0]; $new[0]) * $new[0]
    else error("expected an object") end
  '';
in
''
  (
    config_path=${lib.escapeShellArg path}
    state_path=${lib.escapeShellArg state}
    mkdir -p "$(dirname "$config_path")" "$(dirname "$state_path")"
    # An older generation may have linked the file into the Nix store.
    if [ -L "$config_path" ]; then
      link_tmp=$(mktemp "$config_path.XXXXXX")
      cp -L "$config_path" "$link_tmp" 2>/dev/null || true
      mv "$link_tmp" "$config_path"
    fi
    current='{}'
    if [ -s "$config_path" ] && ! current=$(${read} "$config_path"); then
      echo >&2 "Could not parse $config_path; leaving it unchanged."
      exit 1
    fi
    old='{}'
    if [ -s "$state_path" ]; then
      old=$(cat "$state_path")
    fi
    config_tmp=$(mktemp "$config_path.XXXXXX")
    if ! printf '%s' "$current" \
      | ${jq} --slurpfile old <(printf '%s' "$old") --slurpfile new ${static} ${lib.escapeShellArg filter} \
      | ${write} > "$config_tmp"; then
      rm -f "$config_tmp"
      echo >&2 "Could not merge Nix settings into $config_path."
      exit 1
    fi
    mv "$config_tmp" "$config_path"
    cp ${static} "$state_path"
    chmod u+w "$state_path"
  )
''
