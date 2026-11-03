-- Shared language tools and Go tooling come from their Nix modules.
local nix_provided = {
  biome = true,
  delve = true,
  gofumpt = true,
  goimports = true,
  ["golangci-lint"] = true,
  gopls = true,
  ruff = true,
}

return {
  -- Nix provides the LSP baseline; projects can override it on PATH.
  { "mason-org/mason-lspconfig.nvim", enabled = false },
  {
    "mason-org/mason.nvim",
    cmd = "Mason",
    keys = { { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" } },
    build = ":MasonUpdate",
    opts = function(_, opts)
      -- Project tools win; keep Mason as a formatter/debugger fallback.
      opts.PATH = "append"
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "codelldb",
        "prettier",
        "shfmt",
        "stylua",
        "xmlformatter",
      })
      opts.ensure_installed = vim.tbl_filter(function(pkg)
        return not nix_provided[pkg]
      end, opts.ensure_installed)
    end,
  },
}
