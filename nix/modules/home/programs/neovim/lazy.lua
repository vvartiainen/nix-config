-- This replaces only nvim-nix's bootstrap; the live Homebrew config is unchanged.
local plugins = assert(vim.env.NVIM_NIX_PLUGINS, "Launch this configuration with nvim-nix")
local config = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
vim.opt.rtp:prepend(config)
vim.opt.rtp:prepend(plugins .. "/lazy.nvim")
vim.g.lazyvim_json = config .. "/lazyvim.json"

-- Pin every resolved spec to its Nix package, including nested dependencies.
local packaged = {}
for name in vim.fs.dir(plugins) do
  packaged[#packaged + 1] = { name = name, dir = plugins .. "/" .. name, optional = true, build = false, pin = true }
end

require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    { import = "plugins" },
    { import = "config.nix" },
    packaged,
  },
  defaults = { lazy = false, version = false },
  dev = { path = plugins, patterns = { "." }, fallback = false },
  install = { missing = false },
  checker = { enabled = false },
  change_detection = { enabled = false },
  rocks = { enabled = false },
  pkg = { enabled = false },
  local_spec = false,
  lockfile = vim.fn.stdpath("state") .. "/lazy-lock.json",
  performance = {
    rtp = {
      paths = { config },
      disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" },
    },
  },
})

-- Fail visibly when an added extra needs a package absent from neovim.nix.
for name, plugin in pairs(require("lazy.core.config").plugins) do
  assert(plugin.dir:sub(1, #plugins + 1) == plugins .. "/", "Missing Nix plugin package: " .. name)
  assert(vim.uv.fs_stat(plugin.dir), "Missing Nix plugin package: " .. name)
end
