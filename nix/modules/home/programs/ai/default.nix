{ lib, config, ... }:
let
  permissions = import ./shared/permissions.nix { inherit lib config; };
in
{
  imports = [
    ./hooks/agent-hooks.nix
    ./shared/agents-catalog.nix
    ./shared/backlog.nix
    ./clients/claude/claude.nix
    ./clients/claude/claude-code.nix
    ./shared/cleanup-agent-config.nix
    ../../../../validation/validate-agent-config.nix
    ./clients/codex.nix
    ./clients/cursor-cli.nix
    ./clients/github-copilot-cli.nix
    ./shared/mcp.nix
    ./clients/opencode.nix
    ./clients/pi/pi-coding-agent.nix
    ../../../../validation/repository-check-hooks.nix
  ];

  # Homebrew checks that its cache (or its parent) is writable before use.
  # Create the granted directories before sessions start; their parent is
  # intentionally read-only in the sandbox.
  home.activation.agentCaches = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p ${lib.escapeShellArgs permissions.caches.writePaths}
  '';
}
