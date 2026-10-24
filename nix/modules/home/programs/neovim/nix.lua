return {
  { "mason-org/mason.nvim", enabled = false },
  { "mason-org/mason-lspconfig.nvim", enabled = false },
  { "jay-babu/mason-nvim-dap.nvim", enabled = false },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      -- Parsers and matching queries are built with the plugin by Nix.
      opts.ensure_installed = {}
      opts.auto_install = false
      opts.install_dir = vim.env.NVIM_NIX_PLUGINS .. "/nvim-treesitter"
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      for _, server in pairs(opts.servers) do
        if type(server) == "table" then
          server.mason = false
        end
      end
    end,
  },
}
