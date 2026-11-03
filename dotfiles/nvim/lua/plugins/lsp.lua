return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "mason-org/mason.nvim",
  },

  opts = function(_, opts)
    opts = vim.tbl_deep_extend("force", opts, {
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
    })
    -- Applied after LazyVim's language extras, including TypeScript/Python.
    for name, server in pairs(opts.servers) do
      if server == true then
        opts.servers[name] = { mason = false }
      elseif type(server) == "table" then
        server.mason = false
      end
    end
    return opts
  end,
}
