{ pkgs, ... }:
{
  # Shared by editors, agents and CLI tools without a project dev shell.
  # Go and Rust keep their language servers beside their toolchains.
  home.packages = with pkgs; [
    bash-language-server
    biome
    clang-tools
    docker-compose-language-service
    dockerfile-language-server
    lua-language-server
    marksman
    nil
    oxlint
    pyright
    ruff
    svelte-language-server
    tailwindcss-language-server
    terraform-ls
    tombi
    typescript
    typescript-language-server
    vscode-langservers-extracted
    yaml-language-server
    zls
  ];
}
