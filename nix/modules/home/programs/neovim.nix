{ pkgs, lib, ... }:
let
  configSrc = lib.cleanSourceWith {
    src = ../../../../dotfiles/nvim;
    filter = path: _type: builtins.baseNameOf path != "lazy-lock.json";
  };
  # Include the base parsers, language extras, and custom Treesitter selections.
  treesitter = pkgs.symlinkJoin {
    name = "nvim-treesitter-with-parsers";
    paths = lib.unique (pluginClosure [
      (pkgs.vimPlugins.nvim-treesitter.withPlugins (
        p: with p; [
          bash
          c
          cpp
          css
          diff
          dockerfile
          git_config
          git_rebase
          gitattributes
          gitcommit
          gitignore
          go
          gomod
          gosum
          gowork
          graphql
          hcl
          html
          javascript
          jsdoc
          json
          latex
          lua
          luadoc
          luap
          markdown
          markdown_inline
          ninja
          nix
          printf
          python
          query
          regex
          ron
          rst
          rust
          scss
          svelte
          terraform
          toml
          tsx
          typescript
          typst
          vim
          vimdoc
          vue
          xml
          yaml
          zig
        ]
      ))
    ]);
  };
  pluginClosure = plugins: lib.concatMap (p: [ p ] ++ pluginClosure (p.dependencies or [ ])) plugins;
  # Lazy names sometimes differ from nixpkgs attributes (notably catppuccin and harpoon).
  plugins = {
    "LazyVim" = pkgs.vimPlugins.LazyVim;
    "SchemaStore.nvim" = pkgs.vimPlugins.SchemaStore-nvim;
    "async.nvim" = pkgs.vimPlugins.async-nvim;
    "blink-copilot" = pkgs.vimPlugins.blink-copilot;
    "blink.cmp" = pkgs.vimPlugins.blink-cmp;
    "bufferline.nvim" = pkgs.vimPlugins.bufferline-nvim;
    "catppuccin" = pkgs.vimPlugins.catppuccin-nvim;
    "clangd_extensions.nvim" = pkgs.vimPlugins.clangd_extensions-nvim;
    "conform.nvim" = pkgs.vimPlugins.conform-nvim;
    "copilot.lua" = pkgs.vimPlugins.copilot-lua;
    "crates.nvim" = pkgs.vimPlugins.crates-nvim;
    "dial.nvim" = pkgs.vimPlugins.dial-nvim;
    "flash.nvim" = pkgs.vimPlugins.flash-nvim;
    "friendly-snippets" = pkgs.vimPlugins.friendly-snippets;
    "gitsigns.nvim" = pkgs.vimPlugins.gitsigns-nvim;
    "grug-far.nvim" = pkgs.vimPlugins.grug-far-nvim;
    "harpoon" = pkgs.vimPlugins.harpoon2;
    "inc-rename.nvim" = pkgs.vimPlugins.inc-rename-nvim;
    "lazy.nvim" = pkgs.vimPlugins.lazy-nvim;
    "lazydev.nvim" = pkgs.vimPlugins.lazydev-nvim;
    "lualine.nvim" = pkgs.vimPlugins.lualine-nvim;
    "markdown-preview.nvim" = pkgs.vimPlugins.markdown-preview-nvim;
    "mini.ai" = pkgs.vimPlugins.mini-ai;
    "mini.hipatterns" = pkgs.vimPlugins.mini-hipatterns;
    "mini.icons" = pkgs.vimPlugins.mini-icons;
    "mini.pairs" = pkgs.vimPlugins.mini-pairs;
    "mini.surround" = pkgs.vimPlugins.mini-surround;
    "neotest" = pkgs.vimPlugins.neotest;
    "neotest-golang" = pkgs.vimPlugins.neotest-golang;
    "neotest-jest" = pkgs.vimPlugins.neotest-jest;
    "neotest-python" = pkgs.vimPlugins.neotest-python;
    "neotest-vitest" = pkgs.vimPlugins.neotest-vitest;
    "neotest-zig" = pkgs.vimPlugins.neotest-zig;
    "noice.nvim" = pkgs.vimPlugins.noice-nvim;
    "nui.nvim" = pkgs.vimPlugins.nui-nvim;
    "nvim-autopairs" = pkgs.vimPlugins.nvim-autopairs;
    "nvim-dap" = pkgs.vimPlugins.nvim-dap;
    "nvim-dap-go" = pkgs.vimPlugins.nvim-dap-go;
    "nvim-dap-python" = pkgs.vimPlugins.nvim-dap-python;
    "nvim-dap-ui" = pkgs.vimPlugins.nvim-dap-ui;
    "nvim-dap-virtual-text" = pkgs.vimPlugins.nvim-dap-virtual-text;
    "nvim-lint" = pkgs.vimPlugins.nvim-lint;
    "nvim-lspconfig" = pkgs.vimPlugins.nvim-lspconfig;
    "nvim-nio" = pkgs.vimPlugins.nvim-nio;
    "nvim-treesitter" = treesitter;
    "nvim-treesitter-context" = pkgs.vimPlugins.nvim-treesitter-context;
    "nvim-treesitter-textobjects" = pkgs.vimPlugins.nvim-treesitter-textobjects;
    "nvim-ts-autotag" = pkgs.vimPlugins.nvim-ts-autotag;
    "one-small-step-for-vimkind" = pkgs.vimPlugins.one-small-step-for-vimkind;
    "persistence.nvim" = pkgs.vimPlugins.persistence-nvim;
    "plenary.nvim" = pkgs.vimPlugins.plenary-nvim;
    "refactoring.nvim" = pkgs.vimPlugins.refactoring-nvim;
    "render-markdown.nvim" = pkgs.vimPlugins.render-markdown-nvim;
    "rustaceanvim" = pkgs.vimPlugins.rustaceanvim;
    "sidekick.nvim" = pkgs.vimPlugins.sidekick-nvim;
    "snacks.nvim" = pkgs.vimPlugins.snacks-nvim;
    "todo-comments.nvim" = pkgs.vimPlugins.todo-comments-nvim;
    "tokyonight.nvim" = pkgs.vimPlugins.tokyonight-nvim;
    "trouble.nvim" = pkgs.vimPlugins.trouble-nvim;
    "ts-comments.nvim" = pkgs.vimPlugins.ts-comments-nvim;
    "venv-selector.nvim" = pkgs.vimPlugins.venv-selector-nvim;
    "vim-startuptime" = pkgs.vimPlugins.vim-startuptime;
    "which-key.nvim" = pkgs.vimPlugins.which-key-nvim;
    "yanky.nvim" = pkgs.vimPlugins.yanky-nvim;
    "yazi.nvim" = pkgs.vimPlugins.yazi-nvim;
    "zig.vim" = pkgs.vimPlugins.zig-vim;
  };
  pluginPaths = pkgs.linkFarm "nvim-nix-plugins" (
    lib.mapAttrsToList (name: path: { inherit name path; }) plugins
  );
  configSnapshot = pkgs.runCommand "nvim-nix-config" { } ''
    mkdir -p "$out"
    cp -R ${configSrc}/. "$out/"
    chmod -R u+w "$out"
    cp ${./neovim/lazy.lua} "$out/lua/config/lazy.lua"
    cp ${./neovim/nix.lua} "$out/lua/config/nix.lua"
  '';
  neovim = pkgs.writeShellScriptBin "nvim-nix" ''
    export NVIM_APPNAME=nvim-nix
    export NVIM_NIX_PLUGINS=${pluginPaths}
    # Keep the caller's PATH intact so project dev shells own development tools.
    exec ${lib.getExe pkgs.neovim} --cmd 'set runtimepath^=${configSnapshot}' -u ${configSnapshot}/init.lua "$@"
  '';
in
{
  home.packages = [ neovim ];
}
