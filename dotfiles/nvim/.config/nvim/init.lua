-- Set leader key FIRST
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

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

-- Basic settings
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.smartindent = true
vim.opt.wrap = false
vim.opt.undofile = true
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"

vim.lsp.config('pyright', {})
vim.lsp.config('bashls', {})
vim.lsp.config('lua_ls', {
  settings = { Lua = { diagnostics = { globals = { 'vim' } } } }
})

vim.lsp.enable({ 'pyright', 'bashls', 'lua_ls' })
