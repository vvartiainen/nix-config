return {
  "saghen/blink.cmp",
  ---@type blink.cmp.Config
  opts = {
    completion = {
      list = {
        selection = {
          auto_insert = false,
          preselect = true,
        },
      },
    },
    keymap = {
      preset = "default",
      ["<Tab>"] = {
        "snippet_forward",
        function() -- sidekick next edit suggestion
          return require("sidekick").nes_jump_or_apply()
        end,
        -- function() -- if you are using Neovim's native inline completions
        --   return vim.lsp.inline_completion.get()
        -- end,
        "fallback",
      },
      ["<C-e>"] = {
        function(cmp)
          cmp.show({ providers = { "snippets" } })
        end,
      },
      ["<PageDown>"] = {
        function(cmp)
          cmp.select_next({ count = 5 })
        end,
      },
      ["<PageUp>"] = {
        function(cmp)
          cmp.select_prev({ count = 5 })
        end,
      },
    },
  },
}
