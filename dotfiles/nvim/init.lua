-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Disable Ruby and Perl providers
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0

-- disable spellcheck by default
vim.opt.spell = false
vim.opt.spelllang = ""
vim.opt.spellfile = ""
vim.opt.spellcapcheck = ""
