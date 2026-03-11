-- Set leader key FIRST (before any plugins)
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

    -- Essential plugins
    use 'neovim/nvim-lspconfig'           -- LSP support
    use {
        'nvim-telescope/telescope.nvim',   -- Fuzzy finder
        requires = { {'nvim-lua/plenary.nvim'} }
    }
    use 'folke/which-key.nvim'            -- Keybind helper
    use {
        'nvim-treesitter/nvim-treesitter', -- Syntax highlighting
        run = ':TSUpdate'
    }

    -- OFFENSIVE SECURITY ADDITIONS
    use 'gpanders/editorconfig.nvim'       -- EditorConfig for different projects
    
    -- Better syntax for offsec files
    use 'baskerville/vim-sxhkdrc'          -- SXHKD syntax (useful for keybind files)
    use 'meain/vim-printer'                 -- Print statement debugging
    use 'mattn/emmet-vim'                   -- HTML/CSS expansion (for web testing)
    
    -- Filetype-specific tools
    use 'hashivim/vim-terraform'            -- Terraform syntax (cloud infra)
    use 'stephpy/vim-yaml'                   -- YAML support (nuclei templates)
    use 'elzr/vim-json'                      -- JSON support (nuclei configs)
    
    -- Automatically set up your configuration after cloning packer.nvim
    if packer_bootstrap then
        require('packer').sync()
    end
end)

-- Only configure plugins if they're installed
local function safe_require(module)
    local ok, result = pcall(require, module)
    if ok then
        return result
    else
        return nil
    end
end

-- Which-key setup (only if installed)
local which_key = safe_require("which-key")
if which_key then
    which_key.setup {}
    
    -- Register which-key groups for offsec workflows
    which_key.register({
        ['<leader>c'] = { name = 'Container' },
        ['<leader>e'] = { name = 'Engagement' },
        ['<leader>n'] = { name = 'Notes' },
        ['<leader>m'] = { name = 'MITRE' },
    })
end

-- Enhanced Telescope keybinds for offsec work
vim.keymap.set('n', '<leader>ff', ':Telescope find_files<CR>', { desc = 'Find files' })
vim.keymap.set('n', '<leader>fg', ':Telescope live_grep<CR>', { desc = 'Live grep' })
vim.keymap.set('n', '<leader>fb', ':Telescope buffers<CR>', { desc = 'Find buffers' })
vim.keymap.set('n', '<leader>fh', ':Telescope help_tags<CR>', { desc = 'Find help' })

-- Engagement-specific searches
vim.keymap.set('n', '<leader>el', ':Telescope find_files cwd=~/engage/current/loot/<CR>', { desc = 'Engagement loot' })
vim.keymap.set('n', '<leader>en', ':Telescope find_files cwd=~/engage/current/notes/<CR>', { desc = 'Engagement notes' })
vim.keymap.set('n', '<leader>er', ':Telescope find_files cwd=~/engage/current/recon/<CR>', { desc = 'Engagement recon' })

-- MITRE technique logging helper
vim.keymap.set('n', '<leader>ml', ':!mitre log ', { desc = 'Log MITRE technique' })

-- Quick container access
vim.keymap.set('n', '<leader>ca', ':!c ad<CR>', { desc = 'AD container' })
vim.keymap.set('n', '<leader>cr', ':!c re<CR>', { desc = 'RE container' })
vim.keymap.set('n', '<leader>cw', ':!c web<CR>', { desc = 'Web container' })
vim.keymap.set('n', '<leader>ct', ':!c toolbox<CR>', { desc = 'Toolbox container' })

-- Basic settings
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.smartindent = true
vim.opt.wrap = false
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undofile = true
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.hlsearch = false
vim.opt.incsearch = true
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 50
vim.opt.colorcolumn = "80"

-- LSP Setup (modern approach for Neovim 0.11+)
vim.api.nvim_create_autocmd('User', {
    pattern = 'LspAttach',
    callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if not client then return end

        -- Keybinds that only work when LSP is attached
        vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { buffer = args.buf, desc = 'Go to definition' })
        vim.keymap.set('n', 'K', vim.lsp.buf.hover, { buffer = args.buf, desc = 'Hover documentation' })
        vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, { buffer = args.buf, desc = 'Go to implementation' })
        vim.keymap.set('n', 'gr', vim.lsp.buf.references, { buffer = args.buf, desc = 'References' })
        vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, { buffer = args.buf, desc = 'Rename' })
        vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, { buffer = args.buf, desc = 'Code action' })
    end
})

-- LSP Server configurations
local lspconfig = safe_require('lspconfig')
if lspconfig then
    -- Python
    lspconfig.pyright.setup{}
    
    -- Bash
    lspconfig.bashls.setup{}
    
    -- Lua
    lspconfig.lua_ls.setup{
        settings = {
            Lua = {
                diagnostics = { globals = {'vim'} },
                workspace = { checkThirdParty = false }
            }
        }
    }
    
    -- YAML (for nuclei templates)
    lspconfig.yamlls.setup{
        settings = {
            yaml = {
                schemas = {
                    ["https://json.schemastore.org/nuclei.json"] = "*.yaml",
                }
            }
        }
    }
    
    -- JSON
    lspconfig.jsonls.setup{}
end

-- Treesitter configuration
local treesitter = safe_require('nvim-treesitter.configs')
if treesitter then
    treesitter.setup {
        ensure_installed = {
            "lua", "vim", "vimdoc", "query",
            "python", "bash", "yaml", "json", "html", "css"
        },
        auto_install = true,
        highlight = { enable = true },
        indent = { enable = true },
    }
end

-- Theme - try matugen colors first, fallback to catppuccin
local function load_theme()
    local matugen_ok, matugen_colors = pcall(require, 'matugen-theme')
    if matugen_ok then
        -- Set highlight groups based on matugen colors
        vim.cmd('highlight Normal guibg=' .. matugen_colors.bg .. ' guifg=' .. matugen_colors.fg)
        vim.cmd('highlight LineNr guifg=' .. matugen_colors.fg)
        -- Add more highlights as needed
    else
        -- Fallback to catppuccin
        vim.cmd.colorscheme "catppuccin-mocha"
    end
end

load_theme()

-- Auto-reload and sync on save
vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost init.lua source <afile> | PackerSync
  augroup end
]])
