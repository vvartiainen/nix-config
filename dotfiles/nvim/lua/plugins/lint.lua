return {
  "mfussenegger/nvim-lint",
  opts = {
    linters_by_ft = {
      bash = { "shellcheck" },
      zsh = { "zsh", "shellcheck" },
      sh = { "shellcheck" },
      shell = { "shellcheck" },
      -- sql = { "sqlfluff" },
      -- markdown = { "markdownlint" },
      -- javascript = {  "eslint" },
      -- typescript = {  "eslint" },
      -- typescriptreact = {  "eslint" },
      -- Use the "*" filetype to run linters on all filetypes.
      -- ['*'] = { 'global linter' },
      -- Use the "_" filetype to run linters on filetypes that don't have other linters configured.
      -- ['_'] = { 'fallback linter' },
    },
  },
}
