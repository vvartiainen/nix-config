-- Keep a stable bufferline order:
-- - README.md and TODO.md (in cwd root) are always first, in that order
-- - manual ordering ([B / ]B) and newly opened buffers persist across sessions
local pinned = { "README.md", "TODO.md" }

local function pin_rank(buf)
  local rel = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":.")
  for i, name in ipairs(pinned) do
    if rel == name then
      return i
    end
  end
end

-- Normalize bufferline's custom order: drop closed buffers, append new ones by
-- id (bufferline's own merge is an unstable sort) and move pinned files first.
local function normalize()
  if not package.loaded["bufferline"] then
    return
  end
  local state = require("bufferline.state")
  local utils = require("bufferline.utils")

  local valid = {}
  for _, id in ipairs(utils.get_valid_buffers()) do
    valid[id] = true
  end
  local order, seen = {}, {}
  local function add(id)
    if valid[id] and not seen[id] then
      seen[id] = true
      table.insert(order, id)
    end
  end
  for _, id in ipairs(state.custom_sort or {}) do
    add(id)
  end
  for _, id in ipairs(utils.get_valid_buffers()) do
    add(id)
  end

  local head, tail = {}, {}
  for _, id in ipairs(order) do
    local rank = pin_rank(id)
    if rank then
      table.insert(head, { rank = rank, id = id })
    else
      table.insert(tail, id)
    end
  end
  table.sort(head, function(a, b)
    return a.rank < b.rank or (a.rank == b.rank and a.id < b.id)
  end)
  local ids = vim.tbl_map(function(h)
    return h.id
  end, head)
  vim.list_extend(ids, tail)

  state.custom_sort = ids
  utils.save_positions(ids)
  pcall(require("bufferline.ui").refresh)
end

return {
  "akinsho/bufferline.nvim",
  init = function()
    local group = vim.api.nvim_create_augroup("bufferline_stable_order", { clear = true })
    -- scheduled so it runs after bufferline's own SessionLoadPost restore
    vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete", "SessionLoadPost" }, {
      group = group,
      callback = function()
        vim.schedule(normalize)
      end,
    })
    vim.api.nvim_create_autocmd("User", {
      group = group,
      pattern = "VeryLazy",
      callback = function()
        vim.schedule(normalize)
      end,
    })
    -- sync: the session file is written right after this event
    vim.api.nvim_create_autocmd("User", {
      group = group,
      pattern = "PersistenceSavePre",
      callback = normalize,
    })
  end,
}
