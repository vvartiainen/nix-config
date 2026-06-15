return {
  {
    "folke/lazydev.nvim",
    optional = true,
    opts = {
      library = {
        { path = "LazyVim", words = { "LazyVim" } },
        { path = "snacks.nvim", words = { "Snacks" } },
        { path = "yazi.nvim", words = { "yazi" } },
        { path = "blink.cmp", words = { "blink" } },
        { path = "conform.nvim", words = { "conform" } },
      },
    },
  },
}
