return {
  "mfussenegger/nvim-lint",
  opts = {
    linters = {
      terraform_validate = {
        -- OpenTofu-only syntax (e.g. `encryption` blocks) fails `terraform validate`.
        cmd = function()
          return vim.fn.executable("tofu") == 1 and "tofu" or "terraform"
        end,
      },
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
