{ lib, pkgs }:
let
  inherit (lib) concatMapStringsSep escapeShellArg;

  # ERE matched against the full shell command. Keep just build / darwin-rebuild
  # build allowed; only activation/switch is denied.
  blockedShellPatterns = [
    ''just[[:space:]]+([^;&|[:space:]]+[[:space:]]+)*switch([^[:alnum:]_-]|$)''
    ''nix-darwin[[:space:]]+([^;&|[:space:]]+[[:space:]]+)*(--)?switch([^[:alnum:]_-]|$)''
    ''darwin-rebuild[[:space:]]+([^;&|[:space:]]+[[:space:]]+)*switch([^[:alnum:]_-]|$)''
    ''nix[[:space:]]+run[[:space:]]+([^;&|]+)*nix-darwin([^;&|]*)--[[:space:]]+switch([^[:alnum:]_-]|$)''
  ];

  # Same rules for OpenCode / Pi plugins (JavaScript regex, not POSIX ERE).
  jsBlockedShellPatterns = [
    ''just\s+([^;&|\s]+\s+)*switch([^A-Za-z0-9_-]|$)''
    ''nix-darwin\s+([^;&|\s]+\s+)*(--)?switch([^A-Za-z0-9_-]|$)''
    ''darwin-rebuild\s+([^;&|\s]+\s+)*switch([^A-Za-z0-9_-]|$)''
    ''nix\s+run\s+([^;&|]+)*nix-darwin([^;&|]*)--\s+switch([^A-Za-z0-9_-]|$)''
  ];

  denyUserMessage = "Blocked a nix-darwin apply command. Agents must not run just switch or nix-darwin build --switch.";
  denyAgentMessage = "Apply commands are blocked. Use just build, just build-system, just check, just eval-system, or just show; the user applies the config manually.";

  jsPatternsLiteral = concatMapStringsSep ",\n  " (p: "/${p}/") jsBlockedShellPatterns;

  script = pkgs.writeShellApplication {
    name = "block-nix-apply";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      format=""
      while [ "$#" -gt 0 ]; do
        case "$1" in
          --format)
            format="$2"
            shift 2
            ;;
          *)
            shift
            ;;
        esac
      done

      input=$(cat)
      command=$(printf '%s' "$input" | jq -r '
        def cmd_from_tool_args:
          if (.toolArgs | type) == "string" then
            ((.toolArgs | fromjson?) // {}) | (.command // "")
          elif (.toolArgs | type) == "object" then
            .toolArgs.command // ""
          else
            ""
          end;
        .command // .tool_input.command // cmd_from_tool_args // ""
      ')

      if [ -z "$format" ]; then
        format=$(printf '%s' "$input" | jq -r '
          if has("sandbox") then "cursor"
          elif has("toolName") or has("toolArgs") then "copilot"
          elif has("hook_event_name") then "codex"
          else "cursor" end
        ')
      fi

      patterns=(
      ${concatMapStringsSep "\n" (p: "        ${escapeShellArg p}") blockedShellPatterns}
      )

      blocked=0
      for pat in "''${patterns[@]}"; do
        if [[ "$command" =~ $pat ]]; then
          blocked=1
          break
        fi
      done

      if [ "$blocked" -eq 1 ]; then
        case "$format" in
          copilot)
            jq -n \
              --arg reason ${escapeShellArg denyAgentMessage} \
              '{permissionDecision: "deny", permissionDecisionReason: $reason}'
            ;;
          codex)
            jq -n \
              --arg reason ${escapeShellArg denyAgentMessage} \
              '{
                hookSpecificOutput: {
                  hookEventName: "PreToolUse",
                  permissionDecision: "deny",
                  permissionDecisionReason: $reason
                }
              }'
            ;;
          *)
            jq -n \
              --arg user_message ${escapeShellArg denyUserMessage} \
              --arg agent_message ${escapeShellArg denyAgentMessage} \
              '{permission: "deny", user_message: $user_message, agent_message: $agent_message}'
            ;;
        esac
        exit 0
      fi

      case "$format" in
        copilot)
          jq -n '{permissionDecision: "allow"}'
          ;;
        codex)
          jq -n '{
            hookSpecificOutput: {
              hookEventName: "PreToolUse",
              permissionDecision: "allow"
            }
          }'
          ;;
        *)
          jq -n '{permission: "allow"}'
          ;;
      esac
    '';
  };

  opencodePlugin = pkgs.writeText "block-nix-apply.js" ''
    const PATTERNS = [
      ${jsPatternsLiteral}
    ];

    const DENY_MESSAGE = ${builtins.toJSON denyAgentMessage};

    export const BlockNixApply = async () => ({
      "tool.execute.before": async (input, output) => {
        if (input.tool !== "bash") {
          return;
        }
        const command = output.args?.command ?? "";
        if (PATTERNS.some((pattern) => pattern.test(command))) {
          throw new Error(DENY_MESSAGE);
        }
      },
    });
  '';

  piExtension = pkgs.writeText "block-nix-apply.ts" ''
    const PATTERNS = [
      ${jsPatternsLiteral}
    ];

    const DENY_MESSAGE = ${builtins.toJSON denyAgentMessage};

    export default function (pi) {
      pi.on("tool_call", async (event) => {
        if (event.toolName !== "bash") {
          return;
        }
        const command = event.input?.command ?? "";
        if (PATTERNS.some((pattern) => pattern.test(command))) {
          return { block: true, reason: DENY_MESSAGE };
        }
      });
    }
  '';
in
{
  inherit
    blockedShellPatterns
    denyAgentMessage
    denyUserMessage
    opencodePlugin
    piExtension
    script
    ;

  cursor = {
    hookFileName = "block-nix-apply";
    failClosed = true;
    timeout = 10;
  };

  codex = {
    hookFileName = "block-nix-apply";
    matcher = "^Bash$";
    timeout = 10;
  };

  copilot = {
    hookFileName = "block-nix-apply";
    matcher = "bash";
    timeoutSec = 10;
  };
}
