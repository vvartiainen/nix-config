return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "mason-org/mason.nvim",
    "mason-org/mason-lspconfig.nvim",
  },

  opts = {
    inlay_hints = { enabled = false },
    diagnostics = {
      virtual_text = {
        format = function(diagnostic)
          -- Keep Markdown line-length warnings in floats/lists without inline text.
          if
            diagnostic.source == "markdownlint"
            and (diagnostic.code == "MD013" or diagnostic.message:match("^MD013[/%s]"))
          then
            return nil
          end
          return diagnostic.message
        end,
      },
    },
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
