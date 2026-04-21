return {
  "ThePrimeagen/refactoring.nvim",
  dependencies = {
    "lewis6991/async.nvim",
  },
  lazy = false,
  keys = {
    {
      "<leader>rp",
      function()
        return require("refactoring.debug").print_var({ output_location = "below" }) .. "iw"
      end,
      mode = { "n", "x" },
      desc = "Debug Print Variable",
      expr = true,
    },
    {
      "<leader>rs",
      function()
        return require("refactoring").select_refactor()
      end,
      mode = { "n", "x" },
      desc = "Select refactor",
    },
  },
}
