-- Run from the repository root with NVIM_TEST_PLUGINS pointing to an existing
-- lazy.nvim plugin directory. Reads plugin sources; never installs anything.
local root = assert(vim.uv.cwd())
local plugins = assert(vim.env.NVIM_TEST_PLUGINS, "Set NVIM_TEST_PLUGINS to an existing lazy plugin directory")
local scratch = vim.fn.tempname()
for _, kind in ipairs({ "DATA", "CONFIG", "STATE", "CACHE" }) do
	vim.env["XDG_" .. kind .. "_HOME"] = scratch .. "/" .. kind:lower()
end
vim.api.nvim_create_autocmd("VimLeave", {
	callback = function()
		vim.fn.delete(scratch, "rf")
	end,
})
for _, name in ipairs({ "lazy.nvim", "LazyVim", "mason.nvim", "conform.nvim" }) do
	vim.opt.rtp:append(plugins .. "/" .. name)
end
vim.opt.rtp:append(root .. "/dotfiles/nvim")

-- Merge actual LazyVim LSP, language/formatter/debugger extras and user specs
-- without starting plugins, resolving a registry, or touching live state.
local Config = require("lazy.core.config")
Config.options = vim.deepcopy(Config.defaults)
Config.options.root = plugins
local Plugin = require("lazy.core.plugin")
Config.spec = Plugin.Spec.new(nil, { pkg = false })
require("lazyvim.config").did_init = true
LazyVim.config.json.data = vim.json.decode(table.concat(vim.fn.readfile(root .. "/dotfiles/nvim/lazyvim.json"), "\n"))
LazyVim.config.get_defaults()
local specs = {
	dofile(plugins .. "/LazyVim/lua/lazyvim/plugins/lsp/init.lua"),
	dofile(plugins .. "/LazyVim/lua/lazyvim/plugins/formatting.lua"),
}
for _, extra in ipairs(LazyVim.config.json.data.extras) do
	if extra:match("extras.lang%.") or extra:match("extras.formatting%.") or extra:match("extras.dap%.") then
		table.insert(specs, { import = extra })
	end
end
table.insert(specs, dofile(root .. "/dotfiles/nvim/lua/plugins/lsp.lua"))
table.insert(specs, dofile(root .. "/dotfiles/nvim/lua/plugins/mason.lua"))
table.insert(specs, dofile(root .. "/dotfiles/nvim/lua/plugins/conform.lua"))
Config.spec:parse(specs)
Config.plugins = Config.spec.plugins
for _, notification in ipairs(Config.spec.notifs) do
	assert(notification.level < vim.log.levels.ERROR, notification.msg)
end
assert(not Config.plugins["mason-lspconfig.nvim"], "Mason must not install or auto-enable LSPs")
local lsp = Plugin.values(Config.plugins["nvim-lspconfig"], "opts", false)
-- Markdownlint can prefix its rule with "error". Hide only MD013 inline,
-- preserving the diagnostic for floats/lists and other rules' inline text.
vim.diagnostic.config(lsp.diagnostics)
local diagnostic_buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(diagnostic_buf, 0, -1, false, { string.rep("x", 89) })
local diagnostic_ns = vim.api.nvim_create_namespace("test-markdown-line-length")
for _, message in ipairs({
	"MD013/line-length Line length [Expected: 80; Actual: 89]",
	"error MD013/line-length Line length [Expected: 80; Actual: 89]",
	"MD010/no-hard-tabs Hard tabs",
	"MD0130/other Other rule",
}) do
	local diagnostic = { lnum = 0, col = 80, source = "markdownlint", severity = 2, message = message }
	vim.diagnostic.set(diagnostic_ns, diagnostic_buf, { diagnostic })
	local inline = false
	for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(diagnostic_buf, -1, 0, -1, { details = true })) do
		inline = inline or mark[4].virt_text ~= nil
	end
	assert(inline == (not message:find("MD013/", 1, true)), "Unexpected inline diagnostic: " .. message)
	assert(vim.diagnostic.get(diagnostic_buf)[1].message == message, "Keep diagnostics available in floats/lists")
end
vim.api.nvim_buf_delete(diagnostic_buf, { force = true })
local mason = Plugin.values(Config.plugins["mason.nvim"], "opts", false)
for name, server in pairs(lsp.servers) do
	assert(type(server) ~= "table" or server.mason == false, name .. " still uses Mason")
end
assert(lsp.servers.tsc.enabled and not lsp.servers.ts_ls.enabled, "Keep the selected TypeScript server")
assert(lsp.servers.gopls.settings.gopls.gofumpt, "Preserve Go settings")
assert(lsp.servers.rust_analyzer.enabled == false, "Rustaceanvim owns Rust")
local rust = Plugin.values(Config.plugins["rustaceanvim"], "opts", false)
assert(rust.server.default_settings["rust-analyzer"], "Preserve Rustaceanvim settings")
assert(not rust.server.cmd, "Rustaceanvim must retain external command resolution")

local installs = {}
for _, name in ipairs(mason.ensure_installed) do
	installs[name] = true
end
for _, name in ipairs({ "prettier", "stylua", "codelldb", "js-debug-adapter" }) do
	assert(installs[name], "Lost formatter/debugger fallback: " .. name)
end
for _, name in ipairs({
	"bash-language-server",
	"lua-language-server",
	"gopls",
	"nil",
	"pyright",
	"zls",
	"biome",
	"ruff",
}) do
	assert(not installs[name], "Unexpected Mason LSP install: " .. name)
end
assert(mason.PATH == "append")

-- Check the final Conform policy after extras, not just the local spec.
local formatting = Plugin.values(Config.plugins["conform.nvim"], "opts", false)
local by_ft = formatting.formatters_by_ft
for ft, expected in pairs({
	python = { "ruff_format" },
	go = { "gofmt" },
	rust = { "rustfmt" },
	nix = { "nixfmt" },
	sh = { "shfmt" },
	terraform = { "terraform_fmt" },
	["terraform-vars"] = { "terraform_fmt" },
	zig = { "zigfmt" },
}) do
	assert(vim.deep_equal(by_ft[ft], expected), "Unexpected formatter chain for " .. ft)
end
assert(vim.tbl_contains(by_ft.markdown, "markdownlint-cli2"))
assert(not vim.tbl_contains(by_ft.markdown, "markdownlint"))
assert(not by_ft.sql and not by_ft.zsh, "Do not force undeclared SQL or Bash tools on Zsh")
for _, name in ipairs({ "black", "markdownlint", "rustywind" }) do
	assert(not installs[name], "Obsolete formatter fallback: " .. name)
end
for _, chain in pairs(by_ft) do
	if type(chain) == "table" then
		assert(not vim.tbl_contains(chain, "shellcheck"), "Keep ShellCheck in linting")
	end
end

local web_root = scratch .. "/web"
vim.fn.mkdir(web_root .. "/nested/deep", "p")
vim.fn.writefile({ "{}" }, web_root .. "/.oxfmtrc.json")
vim.fn.writefile({ "{}" }, web_root .. "/nested/biome.json")
vim.fn.writefile({ "{}" }, web_root .. "/nested/deep/.prettierrc")
local function selected(ft, dir, expected)
	local buf = vim.api.nvim_create_buf(false, false)
	vim.api.nvim_buf_set_name(buf, dir .. "/example." .. ft)
	assert(vim.deep_equal(by_ft[ft](buf), { expected }), "Wrong project formatter for " .. ft .. " in " .. dir)
	vim.api.nvim_buf_delete(buf, { force = true })
end
for _, ft in ipairs({ "javascript", "typescript", "json", "css", "svelte" }) do
	selected(ft, web_root, "oxfmt")
	selected(ft, web_root .. "/nested", "biome")
	selected(ft, web_root .. "/nested/deep", "prettier")
end
selected("javascript", scratch, "biome")
selected("json", scratch, "prettier")
require("conform").setup(formatting)
for _, name in ipairs({ "ruff_format", "gofmt", "rustfmt", "nixfmt", "terraform_fmt", "zigfmt", "markdownlint-cli2" }) do
	assert(require("conform").get_formatter_config(name), "Unknown Conform formatter: " .. name)
end

-- Exercise real Mason PATH setup against executable files representing project
-- tools and old Mason installs, including the intentional transitional fallback.
local project_bin = scratch .. "/project/bin"
local mason_root = scratch .. "/mason"
local function executable(dir, name)
	vim.fn.mkdir(dir, "p")
	local path = dir .. "/" .. name
	vim.fn.writefile({ "#!/bin/sh", "exit 0" }, path)
	assert(vim.uv.fs_chmod(path, 493)) -- 0755
	return path
end
local names = { "nil", "gopls", "rust-analyzer", "tsc", "ruff", "biome" }
local baseline_bin = scratch .. "/nix-profile/bin"
for _, name in ipairs(names) do
	executable(project_bin, name)
	executable(baseline_bin, name)
	executable(mason_root .. "/bin", name)
end
local debugger = executable(mason_root .. "/bin", "codelldb")
local legacy = executable(mason_root .. "/bin", "legacy-language-server")
-- Keep the synthetic case independent of debuggers already in a dev shell.
vim.env.PATH = project_bin .. ":" .. baseline_bin
require("mason").setup(vim.tbl_extend("force", mason, { install_root_dir = mason_root }))
for _, name in ipairs(names) do
	assert(vim.fn.exepath(name) == project_bin .. "/" .. name, "Mason shadows project " .. name)
end
assert(vim.fn.exepath("codelldb") == debugger, "Mason debugger fallback unavailable")
assert(vim.fn.exepath("legacy-language-server") == legacy, "Legacy fallback changed unexpectedly")
-- With no project overrides, the shared Nix baseline still precedes Mason.
vim.env.PATH = baseline_bin .. ":" .. mason_root .. "/bin"
for _, name in ipairs(names) do
	assert(vim.fn.exepath(name) == baseline_bin .. "/" .. name, "Missing baseline " .. name)
end
print("Editor tools: merged LSP/formatter specs, project selection and executable precedence passed")
