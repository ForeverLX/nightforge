-- Set leader key FIRST
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Bootstrap packer
local ensure_packer = function()
  local fn = vim.fn
  local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
  if fn.empty(fn.glob(install_path)) > 0 then
    fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
    vim.cmd [[packadd packer.nvim]]
    return true
  end
  return false
end

local packer_bootstrap = ensure_packer()

-- Plugin setup
require('packer').startup(function(use)
    use 'wbthomason/packer.nvim'
    use 'neovim/nvim-lspconfig'
    use {
        'nvim-telescope/telescope.nvim',
        requires = { {'nvim-lua/plenary.nvim'} }
    }
    use 'folke/which-key.nvim'
    use {
        'nvim-treesitter/nvim-treesitter',
        run = ':TSUpdate'
    }
    use { "catppuccin/nvim", as = "catppuccin" }

    if packer_bootstrap then
        require('packer').sync()
    end
end)

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

-- Modern LSP Setup (Silencing the 0.11 Framework Warning)
-- We avoid the 'lspconfig' variable entirely to prevent indexing the deprecated meta-table.
vim.api.nvim_create_autocmd('User', {
    pattern = 'PackerComplete',
    callback = function()
        local lsp = require('lspconfig')
        lsp.pyright.setup{}
        lsp.bashls.setup{}
        lsp.lua_ls.setup{
            settings = { Lua = { diagnostics = { globals = {'vim'} } } }
        }
    end
})

-- Immediate setup for subsequent launches
local ok, lsp = pcall(require, 'lspconfig')
if ok then
    lsp.pyright.setup{}
    lsp.bashls.setup{}
    lsp.lua_ls.setup{
        settings = { Lua = { diagnostics = { globals = {'vim'} } } }
    }
end

-- Theme
vim.cmd.colorscheme "catppuccin-mocha"
