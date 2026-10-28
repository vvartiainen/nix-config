-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local wk = require("which-key")
wk.add({
  -- Show hidden
  { "<leader><space>", LazyVim.pick("files", { hidden = true }), desc = "Find Files (Root Dir)" },
})

-- € to $ for easier access on Finnish layout
vim.api.nvim_set_keymap("n", "€", "$", { silent = true, desc = "End of line" })
vim.api.nvim_set_keymap("o", "€", "$", { silent = true, desc = "End of line" })
vim.api.nvim_set_keymap("x", "€", "$", { silent = true, desc = "End of line" })
vim.api.nvim_set_keymap("s", "€", "$", { silent = true, desc = "End of line" })
vim.api.nvim_set_keymap("v", "€", "$", { silent = true, desc = "End of line" })

-- ä and ö for easier next function/method/etc navigation, Ä and Ö for } and {
-- The key after [ or ] is read unmapped, so the pairs need their own mappings
for lhs, rhs in pairs({
  ["ä"] = "]",
  ["ö"] = "[",
  ["ää"] = "]]",
  ["öö"] = "[[",
  ["äö"] = "][",
  ["öä"] = "[]",
  ["Ä"] = "}",
  ["Ö"] = "{",
  ["äÄ"] = "]}",
  ["öÖ"] = "[{",
}) do
  vim.keymap.set({ "n", "x", "o" }, lhs, rhs, { remap = true })
end

-- floating terminal toggle
-- vim.keymap.set("n", "<C-t>", function()
--   Snacks.terminal()
-- end, { desc = "Terminal (cwd)" })
-- vim.keymap.set("t", "<C-t>", function()
--   Snacks.terminal()
-- end, { desc = "Terminal (cwd)" })
