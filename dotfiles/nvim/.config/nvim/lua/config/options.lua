-- Options — organized vim settings
-- Heavily inspired by omerxx/dotfiles

local opt = vim.opt

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Indentation
opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.smartindent = true

-- Wrapping & scrolling
opt.wrap = false
opt.scrolloff = 8

-- Undo & history
opt.undofile = true

-- Appearance
opt.termguicolors = true
opt.signcolumn = "yes"

-- Cursor
opt.cursorline = true

-- Search
opt.hlsearch = true
opt.incsearch = true
opt.ignorecase = true
opt.smartcase = true

-- Completion
opt.completeopt = "menu,menuone,noselect"

-- Splits
opt.splitright = true
opt.splitbelow = true

-- Timeout
opt.timeoutlen = 300

-- Folding
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldlevel = 99
