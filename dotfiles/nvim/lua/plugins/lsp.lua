return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "mason-org/mason.nvim",
    "mason-org/mason-lspconfig.nvim",
    "WhoIsSethDaniel/mason-tool-installer.nvim",
  },

  opts = {
    inlay_hints = { enabled = false },
    servers = {
      biome = {},
      bashls = {},
      svelte = {},
      sourcekit = {},
      gopls = {},
      tailwindcss = {},
      terraformls = {},
      marksman = {},
      -- postgres_lsp = {},
    },
  },
}
