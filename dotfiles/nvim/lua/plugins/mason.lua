-- Go tooling comes from Nix (nix/modules/home/programs/go.nix), including
-- the tools the LazyVim Go extra would otherwise install.
local nix_provided = {
  delve = true,
  gofumpt = true,
  goimports = true,
  ["golangci-lint"] = true,
  gopls = true,
}

return {
  { "mason-org/mason-lspconfig.nvim" },
  {
    "mason-org/mason.nvim",
    cmd = "Mason",
    keys = { { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" } },
    build = ":MasonUpdate",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "bash-language-server",
        "biome",
        "black",
        "codelldb",
        "html-lsp",
        "jq",
        "json-lsp",
        "lua-language-server",
        "markdownlint",
        "marksman",
        "prettier",
        "prettierd",
        "postgres-language-server",
        "sqlfluff",
        "rustywind",
        "shellcheck",
        "shfmt",
        "stylua",
        "svelte-language-server",
        "tailwindcss-language-server",
        "terraform-ls",
        "tombi",
        "yaml-language-server",
        "zls",
      })
      opts.ensure_installed = vim.tbl_filter(function(pkg)
        return not nix_provided[pkg]
      end, opts.ensure_installed)
    end,
  },
}
