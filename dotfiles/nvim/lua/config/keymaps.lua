-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local wk = require("which-key")
wk.add({
  -- Show hidden
  { "<leader><space>", LazyVim.pick("files", { hidden = true }), desc = "Find Files (Root Dir)" },
})

-- Yank the current file path, e.g. for referring to it in AI agents
local function yank_path(modifier, with_lines)
  return function()
    local path = vim.fn.expand("%" .. modifier)
    if path == "" then
      return vim.notify("No file path", vim.log.levels.WARN)
    end
    if with_lines then
      local first, last = vim.fn.line("v"), vim.fn.line(".")
      if first > last then
        first, last = last, first
      end
      path = path .. ":" .. (first == last and first or first .. "-" .. last)
    end
    vim.fn.setreg("+", path)
    vim.notify("Copied " .. path)
  end
end

wk.add({
  { "<leader>y", group = "yank path" },
  { "<leader>yp", yank_path(":."), desc = "Yank Relative Path" },
  { "<leader>yP", yank_path(":p"), desc = "Yank Absolute Path" },
  { "<leader>yl", yank_path(":.", true), mode = { "n", "x" }, desc = "Yank Relative Path:Line(s)" },
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
