return {
  "mfussenegger/nvim-lint",
  opts = {
    linters = {
      -- OpenTofu-only syntax (e.g. `encryption` blocks) fails `terraform validate`.
      -- The built-in linter is a function, so wrap it: a table here would
      -- replace it and drop its args and parser.
      terraform_validate = function()
        local linter = require("lint.linters.terraform_validate")()
        if vim.fn.executable("tofu") == 1 then
          linter.cmd = "tofu"
        end
        return linter
      end,
    },
    linters_by_ft = {
      bash = { "shellcheck" },
      zsh = { "shellcheck" },
      sh = { "shellcheck" },
      shell = { "shellcheck" },
      -- Use the "*" filetype to run linters on all filetypes.
      -- ['*'] = { 'global linter' },
      -- Use the "_" filetype to run linters on filetypes that don't have other linters configured.
      -- ['_'] = { 'fallback linter' },
    },
  },
}
