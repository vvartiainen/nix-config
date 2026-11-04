{ lib, config, ... }:
let
  permissions = import ./permissions.nix { inherit lib config; };
in
{
  imports = [
    ./agents-catalog.nix
    ./backlog.nix
    ./claude.nix
    ./claude-code.nix
    ./cleanup-agent-config.nix
    ./validate-agent-config.nix
    ./codex.nix
    ./cursor-cli.nix
    ./github-copilot-cli.nix
    ./mcp.nix
    ./opencode.nix
    ./pi-coding-agent.nix
    ./terminal-status.nix
  ];

  # Homebrew checks that its cache (or its parent) is writable before use.
  # Create the granted directories before sessions start; their parent is
  # intentionally read-only in the sandbox.
  home.activation.agentCaches = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p ${lib.escapeShellArgs permissions.caches.writePaths}
  '';
}
