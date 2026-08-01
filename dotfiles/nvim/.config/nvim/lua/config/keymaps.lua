-- Keymaps — omerxx-style keybindings
-- Leader key is set in init.lua (space)

local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Better window navigation
map("n", "<C-h>", "<C-w>h", opts)
map("n", "<C-j>", "<C-w>j", opts)
map("n", "<C-k>", "<C-w>k", opts)
map("n", "<C-l>", "<C-w>l", opts)

-- Resize windows using Ctrl + arrows
map("n", "<C-Up>", "<cmd>resize +2<CR>", opts)
map("n", "<C-Down>", "<cmd>resize -2<CR>", opts)
map("n", "<C-Left>", "<cmd>vertical resize -2<CR>", opts)
map("n", "<C-Right>", "<cmd>vertical resize +2<CR>", opts)

-- Buffer management
map("n", "<leader>q", "<cmd>bdelete<CR>", { desc = "Close buffer" })
map("n", "<leader>Q", "<cmd>qall<CR>", { desc = "Quit all" })
map("n", "<leader>l", "<cmd>bn<CR>", { desc = "Next buffer" })
map("n", "<leader>h", "<cmd>bp<CR>", { desc = "Previous buffer" })

-- Tab management
map("n", "<leader>tn", "<cmd>tabnew<CR>", { desc = "New tab" })
map("n", "<leader>tc", "<cmd>tabclose<CR>", { desc = "Close tab" })
map("n", "<leader>to", "<cmd>tabonly<CR>", { desc = "Close other tabs" })

-- Better escape from insert mode
map("i", "jk", "<Esc>", opts)
map("i", "kj", "<Esc>", opts)

-- Clear search highlights
map("n", "<Esc>", "<cmd>nohlsearch<CR>", opts)

-- Keep cursor centered when jumping
map("n", "n", "nzzzv", opts)
map("n", "N", "Nzzzv", opts)
map("n", "J", "mzJ`z", opts)

-- Paste without yanking replaced text
map("x", "p", '"_dP', opts)

-- Quick save
map("n", "<leader>w", "<cmd>write<CR>", { desc = "Save file" })
map("n", "<leader>W", "<cmd>wall<CR>", { desc = "Save all" })

-- Better indentation
map("v", "<", "<gv", opts)
map("v", ">", ">gv", opts)

-- Move lines in visual mode
map("v", "J", ":m '>+1<CR>gv=gv", opts)
map("v", "K", ":m '<-2<CR>gv=gv", opts)

-- Yank to end of line
map("n", "Y", "y$", opts)
