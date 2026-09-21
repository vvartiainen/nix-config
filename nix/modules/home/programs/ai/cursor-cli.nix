{
  lib,
  pkgs,
  config,
  ...
}:
let
  jsonFormat = pkgs.formats.json { };
  jq = lib.getExe pkgs.jq;
  permissions = import ./permissions.nix { inherit lib; };
  hooks = import ./hooks.nix { inherit lib pkgs; };
  cursorConfigDir = "${config.xdg.configHome}/cursor";
  cursorHooksDir = "${config.home.homeDirectory}/.cursor/hooks";
  cursorHookPath = "${cursorHooksDir}/${hooks.cursor.hookFileName}";
  cursorHook = {
    command = "${cursorHookPath} --format cursor";
    inherit (hooks.cursor) failClosed timeout;
  };
  staticHook = jsonFormat.generate "cursor-block-nix-apply-hook.json" cursorHook;

  # Cursor CLI self-repairs and persists some keys into cli-config.json, so
  # this file has to stay writable. Nix settings are merged on activation.
  settings = {
    version = 1;
    editor.vimMode = false;
    permissions = {
      inherit (permissions.cursor) allow deny;
    };
    sandbox = {
      mode = "enabled";
      networkAccess = "user_config_with_defaults";
    };
    attribution = {
      attributeCommitsToAgent = false;
      attributePRsToAgent = false;
      notifications = true;
    };
  };

  sandboxSettings = {
    additionalReadonlyPaths = permissions.sandboxReadonlyPaths config.xdg;
  };

  staticSettings = jsonFormat.generate "cursor-cli-config.json" settings;
  staticSandbox = jsonFormat.generate "cursor-sandbox.json" sandboxSettings;
in
{
  home.sessionVariables.CURSOR_CONFIG_DIR = cursorConfigDir;

  home.file.".cursor/hooks/${hooks.cursor.hookFileName}".source = lib.getExe hooks.script;

  home.packages = [
    pkgs.cursor-cli
    (pkgs.runCommand "cursor-cli-agent" { } ''
      mkdir -p $out/bin
      ln -s ${lib.getExe pkgs.cursor-cli} $out/bin/agent
    '')
  ];

  home.activation.cursorCliConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    merge_cursor_config() {
      config_path="$1"
      static_path="$2"
      mkdir -p "$(dirname "$config_path")"
      if [ -L "$config_path" ]; then
        rm -f "$config_path"
      fi
      if [ ! -e "$config_path" ]; then
        echo '{}' > "$config_path"
      fi
      if ! ${jq} -S '. * $static[0]' \
        --slurpfile static "$static_path" \
        "$config_path" > "$config_path.tmp" 2>/dev/null; then
        ${jq} -S '.' "$static_path" > "$config_path.tmp"
      fi
      mv "$config_path.tmp" "$config_path"
    }

    merge_cursor_config \
      "${cursorConfigDir}/cli-config.json" \
      ${staticSettings}
    merge_cursor_config \
      "${cursorConfigDir}/sandbox.json" \
      ${staticSandbox}
  '';

  # Upsert this hook without replacing other entries (for example herdr).
  home.activation.cursorAgentHooks = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    hooks_path="${config.home.homeDirectory}/.cursor/hooks.json"
    mkdir -p "$(dirname "$hooks_path")"
    if [ -L "$hooks_path" ]; then
      rm -f "$hooks_path"
    fi
    if [ ! -e "$hooks_path" ]; then
      echo '{}' > "$hooks_path"
    fi
    if ! ${jq} -S --slurpfile hook ${staticHook} '
      .version = (.version // 1)
      | .hooks = (.hooks // {})
      | .hooks.beforeShellExecution = (
          ((.hooks.beforeShellExecution // []) | map(select(.command != $hook[0].command)))
          + $hook
        )
    ' "$hooks_path" > "$hooks_path.tmp" 2>/dev/null; then
      ${jq} -S --slurpfile hook ${staticHook} '
        {version: 1, hooks: {beforeShellExecution: $hook}}
      ' > "$hooks_path.tmp"
    fi
    mv "$hooks_path.tmp" "$hooks_path"
  '';
}
