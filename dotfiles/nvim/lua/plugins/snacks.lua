return {
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    explorer = {
      layout = {},
    },
    picker = {
      sources = {
        explorer = {
          layout = {
            layout = {
              position = "right",
            },
          },
        },
      },
    },
  },
}
