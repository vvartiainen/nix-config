return {
  { "nvim-mini/mini.pairs", enabled = false },
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {
      check_ts = true,
      enable_bracket_in_quote = false,
      ts_config = {
        toml = { "string", "comment" },
      },
    },
    keys = {
      {
        "<leader>up",
        function()
          require("nvim-autopairs").toggle()
        end,
        desc = "Toggle Auto Pairs",
      },
    },
  },
}
