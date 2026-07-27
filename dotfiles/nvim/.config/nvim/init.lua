-- Set leader key FIRST
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Load config modules (options, keymaps, autocmds)
require("config.options")
require("config.keymaps")
require("config.autocmds")

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins", {
  rocks = { enabled = false },
})

vim.lsp.config('pyright', {})
vim.lsp.config('bashls', {})
vim.lsp.config('lua_ls', {
  settings = { Lua = { diagnostics = { globals = { 'vim' } } } }
})

vim.lsp.enable({ 'pyright', 'bashls', 'lua_ls' })
require("matugen-theme")
