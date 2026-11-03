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
  --- @param opts conform.setupOpts
  opts = function(_, opts)
    -- Override after language extras so they don't chain competing formatters.
    local formatters = {
      bash = { "shfmt" },
      sh = { "shfmt" },
      go = { "gofmt" },
      python = { "ruff_format" },
      rust = { "rustfmt" },
      terraform = { "terraform_fmt" },
      ["terraform-vars"] = { "terraform_fmt" },
      zig = { "zigfmt" },
      xml = { "xmlformatter" },
    }
    for _, ft in ipairs({ "javascript", "javascriptreact", "typescript", "typescriptreact" }) do
      formatters[ft] = web_formatter("biome")
    end
    for _, ft in ipairs({ "json", "jsonc", "css", "scss", "svelte", "vue", "astro" }) do
      formatters[ft] = web_formatter("prettier")
    end
    for ft, tools in pairs(formatters) do
      opts.formatters_by_ft[ft] = tools
    end
    -- Lua, Nix, Markdown and other markup retain their enabled extras' defaults.
    -- ShellCheck remains a diagnostic tool in lint.lua; SQL has no global owner.
  end,
}
