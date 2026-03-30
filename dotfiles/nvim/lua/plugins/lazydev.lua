return {
  {
    "folke/lazydev.nvim",
    optional = true,
    opts = {
      library = {
        { path = "snacks.nvim", words = { "snacks" } },
        { path = "yazi.nvim", words = { "yazi" } },
        { path = "blink.cmp", words = { "blink" } },
        { path = "conform.nvim", words = { "conform" } },
      },
    },
  },
}
