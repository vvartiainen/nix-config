local function biome_lsp_or_prettier()
  local root_dir = require("lspconfig").util.root_pattern("package.json")(vim.fn.getcwd())
  local has_prettier = vim.fs.find({
    ".prettierrc",
    ".prettierrc.json",
    ".prettierrc.yml",
    ".prettierrc.yaml",
    ".prettierrc.json5",
    ".prettierrc.js",
    ".prettierrc.cjs",
    ".prettierrc.toml",
    "prettier.config.js",
    "prettier.config.cjs",
  }, { path = root_dir, stop = root_dir, upward = true })[1]
  if has_prettier then
    return { "prettier" }
  end
  return { "biome" }
end

return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      bash = { "shfmt", "shellcheck" },
      css = { "prettier" },
      go = { "gofmt" },
      html = { "prettier" },
      javascript = biome_lsp_or_prettier,
      javascriptreact = biome_lsp_or_prettier,
      json = { "prettier" },
      lua = { "stylua" },
      markdown = { "markdownlint" },
      python = { "black" },
      rust = { "rustanalyzer" },
      scss = { "prettier" },
      sh = { "shfmt", "shellcheck" },
      shell = { "shfmt", "shellcheck" },
      sql = { "pg_format" },
      -- sql = { "sqlfluff" },
      svelte = { "prettier", "rustywind" },
      terraform = { "terraform_fmt" },
      tf = { "terraform_fmt" },
      tfvars = { "terraform_fmt" },
      typescript = biome_lsp_or_prettier,
      typescriptreact = biome_lsp_or_prettier,
      xml = { "xmlformatter" },
      yaml = { "prettier" },
      zsh = { "shfmt", "shellcheck" },
    },
  },
}
