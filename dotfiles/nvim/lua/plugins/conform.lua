-- JS/TS formatter follows the nearest config in the workspace
local web_formatters = {
  { "oxfmt", { ".oxfmtrc.json", ".oxfmtrc.jsonc", "oxfmt.config.ts" } },
  { "biome", { "biome.json", "biome.jsonc", ".biome.json", ".biome.jsonc" } },
  {
    "prettier",
    {
      ".prettierrc",
      ".prettierrc.json",
      ".prettierrc.yml",
      ".prettierrc.yaml",
      ".prettierrc.json5",
      ".prettierrc.js",
      ".prettierrc.cjs",
      ".prettierrc.mjs",
      ".prettierrc.ts",
      ".prettierrc.toml",
      "prettier.config.js",
      "prettier.config.cjs",
      "prettier.config.mjs",
      "prettier.config.ts",
    },
  },
}

local function web_formatter(fallback)
  return function(bufnr)
    local best, best_root
    for _, f in ipairs(web_formatters) do
      local root = vim.fs.root(bufnr, f[2])
      if root and (not best_root or #root > #best_root) then
        best, best_root = f[1], root
      end
    end
    return { best or fallback }
  end
end

return {
  "stevearc/conform.nvim",
  --- @type conform.setupOpts
  opts = {
    formatters_by_ft = {
      bash = { "shfmt", "shellcheck" },
      css = { "prettier" },
      go = { "gofmt" },
      html = { "prettier" },
      javascript = web_formatter("biome"),
      javascriptreact = web_formatter("biome"),
      json = web_formatter("prettier"),
      jsonc = web_formatter("prettier"),
      lua = { "stylua" },
      markdown = { "markdownlint" },
      python = { "black" },
      scss = { "prettier" },
      sh = { "shfmt", "shellcheck" },
      shell = { "shfmt", "shellcheck" },
      sql = { "pg_format" },
      -- sql = { "sqlfluff" },
      svelte = { "prettier", "rustywind" },
      terraform = { "terraform_fmt" },
      tf = { "terraform_fmt" },
      tfvars = { "terraform_fmt" },
      typescript = web_formatter("biome"),
      typescriptreact = web_formatter("biome"),
      xml = { "xmlformatter" },
      yaml = { "prettier" },
      zsh = { "shfmt", "shellcheck" },
    },
  },
}
