{ ... }:
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
  ];
}
