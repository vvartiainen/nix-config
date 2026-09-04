{
  lib,
  pkgs,
  config,
  ...
}:
let
  jsonFormat = pkgs.formats.json { };
  jq = lib.getExe pkgs.jq;

  # OpenCode updates its config through commands such as `opencode mcp add`.
  # Keep it as a normal file and merge the declarative defaults on activation.
  settings = {
    "$schema" = "https://opencode.ai/config.json";
    model = "openai/gpt-5.6-sol";
    lsp.typescript = {
      command = [
        "${config.xdg.dataHome}/mise/shims/tsc"
        "--lsp"
        "--stdio"
      ];
      extensions = [
        ".ts"
        ".tsx"
        ".js"
        ".jsx"
        ".mjs"
        ".cjs"
        ".mts"
        ".cts"
      ];
    };
    permission = {
      bash = {
        "*" = "ask";
        "git status *" = "allow";
        "git diff *" = "allow";
        "grep *" = "allow";
        "npm run test *" = "allow";
        "npm run build *" = "allow";
        "npm run format *" = "allow";
        "npm test *" = "allow";
        "npx vitest *" = "allow";
        "npx tsc *" = "allow";
        "npx eslint *" = "allow";
        "terraform fmt *" = "allow";
        "terraform validate *" = "allow";
      };
      read = {
        "*" = "allow";
        "*.env" = "deny";
        "*.env.*" = "deny";
        "*.env.example" = "allow";
      };
    };
  };

  tuiSettings = {
    "$schema" = "https://opencode.ai/tui.json";
    theme = "catppuccin";
  };

  staticSettings = jsonFormat.generate "opencode-config.json" settings;
  staticTuiSettings = jsonFormat.generate "opencode-tui.json" tuiSettings;
in
{
  programs.opencode = {
    enable = true;
    package = null;
  };

  home.sessionVariables.OPENCODE_EXPERIMENTAL_LSP_TOOL = "true";

  home.activation.opencodeConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    merge_opencode_config() {
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

    merge_opencode_config \
      "${config.xdg.configHome}/opencode/opencode.json" \
      ${staticSettings}
    merge_opencode_config \
      "${config.xdg.configHome}/opencode/tui.json" \
      ${staticTuiSettings}
  '';
}
