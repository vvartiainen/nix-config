local wk = require("which-key")
wk.add({
  { "<leader>C", function() end, icon = "", desc = "copilot" },
})

return {
  "zbirenbaum/copilot.lua",
  cmd = "Copilot",
  keys = {
    { "<leader>Cs", "<cmd>lua require('copilot').setup({})<CR>", desc = "Setup Copilot" },
    { "<leader>Ce", "<cmd>Copilot enable<CR>", desc = "Enable Copilot" },
    { "<leader>Cd", "<cmd>Copilot disable<CR>", desc = "Disable Copilot" },
    { "<leader>Cm", "<cmd>CopilotChatModels<CR>", desc = "Choose Copilot model" },
  },
  opts = {
    filetypes = {
      css = true,
      go = true,
      javascript = true,
      javascriptreact = true,
      lua = true,
      sh = true,
      svelte = true,
      tf = true,
      terraform = true,
      typescript = true,
      typescriptreact = true,
      ["*"] = false,
    },
  },
  config = function()
    -- Manually setup and loaded via keymaps.lua
  end,
}
