-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local wk = require("which-key")
wk.add({
  -- Copilot enable manually by setup
  { "<leader>C", function() end, icon = "", desc = "copilot" },
  { "<leader>Cs", "<cmd>lua require('copilot').setup({})<CR>", icon = "", desc = "Setup Copilot" },
  { "<leader>Ce", "<cmd>Copilot enable<CR>", icon = "", desc = "Enable Copilot" },
  { "<leader>Cd", "<cmd>Copilot disable<CR>", icon = "", desc = "Disable Copilot" },
  { "<leader>Cm", "<cmd>CopilotChatModels<CR>", icon = "", desc = "Choose Copilot model" },

  -- Show hidden
  { "<leader><space>", LazyVim.pick("files", { hidden = true }), desc = "Find Files (Root Dir)" },
})

-- € to $ for easier access on Finnish layout
vim.api.nvim_set_keymap("n", "€", "$", { silent = true, desc = "End of line" })
vim.api.nvim_set_keymap("o", "€", "$", { silent = true, desc = "End of line" })
vim.api.nvim_set_keymap("x", "€", "$", { silent = true, desc = "End of line" })
vim.api.nvim_set_keymap("s", "€", "$", { silent = true, desc = "End of line" })
vim.api.nvim_set_keymap("v", "€", "$", { silent = true, desc = "End of line" })

-- ä and ö for easier next function/method/etc navigation
vim.api.nvim_set_keymap("n", "ä", "]", {})
vim.api.nvim_set_keymap("n", "ö", "[", {})

-- floating terminal toggle
vim.keymap.set("n", "<C-t>", function()
  Snacks.terminal()
end, { desc = "Terminal (cwd)" })
vim.keymap.set("t", "<C-t>", function()
  Snacks.terminal()
end, { desc = "Terminal (cwd)" })
