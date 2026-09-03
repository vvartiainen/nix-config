{ lib, pkgs, ... }:
let
  jsonFormat = pkgs.formats.json { };
  mcpNixos = lib.getExe pkgs.mcp-nixos;
in
{
  home.packages = [ pkgs.mcp-nixos ];

  home.file.".cursor/mcp.json".source = jsonFormat.generate "cursor-mcp.json" {
    mcpServers = {
      nixos = {
        command = mcpNixos;
      };
    };
  };

  programs.github-copilot-cli.mcpServers.nixos = {
    type = "local";
    command = mcpNixos;
    tools = [ "*" ];
  };
}
