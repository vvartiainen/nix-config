return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "mason-org/mason.nvim",
    "mason-org/mason-lspconfig.nvim",
  },

  opts = {
    inlay_hints = { enabled = false },
    servers = {
      biome = {},
      bashls = {},
      svelte = {},
      sourcekit = {},
      gopls = { mason = false }, -- from Nix, see go.nix
      tailwindcss = {},
      terraformls = {},
      tombi = {},
      marksman = {},
      -- postgres_lsp = {},
    },
  },
}
