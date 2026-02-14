-- Minimal nvim config (bootstrap-safe, exploit-dev capable)

local fn = vim.fn
local lazypath = fn.stdpath("data") .. "/lazy/lazy.nvim"

vim.g.mapleader = " "
vim.g.maplocalleader = " "

if not (vim.uv or vim.loop).fs_stat(lazypath) then
  fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath
  })
end
vim.opt.rtp:prepend(lazypath)

-- Basic ergonomics
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.termguicolors = true

require("lazy").setup({
  { "nvim-lua/plenary.nvim" },

  -- Telescope (rg/fd)
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local telescope = require("telescope")
      telescope.setup({
        defaults = {},
        pickers = {
          find_files = {
            find_command = { "fd", "--type", "f", "--hidden", "--exclude", ".git" },
          },
        },
      })
      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files (fd)" })
      vim.keymap.set("n", "<leader>fg", builtin.live_grep,  { desc = "Live grep (rg)" })
      vim.keymap.set("n", "<leader>fb", builtin.buffers,    { desc = "Buffers" })
    end,
  },

  -- Treesitter (guarded: no crash on first run)
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      local ok, ts = pcall(require, "nvim-treesitter.configs")
      if not ok then return end
      ts.setup({
        highlight = { enable = true },
        ensure_installed = { "c", "lua", "bash", "python" },
      })
    end,
  },

  -- LSP configs provider (no require('lspconfig') framework usage)
  {
    "neovim/nvim-lspconfig",
    config = function()
      -- Nvim 0.11+ native style; nvim-lspconfig registers server configs when loaded
      vim.lsp.enable({ "bashls", "pyright", "clangd" })

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local opts = { buffer = args.buf }
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
          vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
          vim.keymap.set("n", "K",  vim.lsp.buf.hover, opts)
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
          vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
        end,
      })
    end,
  },

  -- Mason (optional UI)
  {
    "mason-org/mason.nvim",
    config = function()
      require("mason").setup({})
    end,
  },

  -- DAP (guarded)
  {
    "mfussenegger/nvim-dap",
    config = function()
      local ok, dap = pcall(require, "dap")
      if not ok then return end

      local function first_exe(candidates)
        for _, c in ipairs(candidates) do
          if fn.executable(c) == 1 then return c end
        end
        return nil
      end

      local lldb_adapter = first_exe({ "lldb-dap", "lldb-vscode" })
      if lldb_adapter then
        dap.adapters.lldb = { type = "executable", command = lldb_adapter, name = "lldb" }
        dap.configurations.c = {
          {
            name = "Launch (lldb)",
            type = "lldb",
            request = "launch",
            program = function()
              return fn.input("Path to executable: ", fn.getcwd() .. "/", "file")
            end,
            cwd = "${workspaceFolder}",
            stopOnEntry = false,
            args = {},
          },
        }
        dap.configurations.cpp = dap.configurations.c
      end

      vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "DAP: breakpoint" })
      vim.keymap.set("n", "<leader>dc", dap.continue,          { desc = "DAP: continue" })
      vim.keymap.set("n", "<leader>do", dap.step_over,         { desc = "DAP: step over" })
      vim.keymap.set("n", "<leader>di", dap.step_into,         { desc = "DAP: step into" })
      vim.keymap.set("n", "<leader>dO", dap.step_out,          { desc = "DAP: step out" })
    end,
  },
})

-- =========================
-- Exploit Dev Enhancements
-- =========================

-- Quick compile (C)
vim.keymap.set("n", "<leader>mc", function()
  vim.cmd("write")
  vim.cmd("!clang -Wall -Wextra -g % -o %<")
end, { desc = "Make (clang)" })

-- Quick run compiled binary
vim.keymap.set("n", "<leader>mr", function()
  vim.cmd("!./%<")
end, { desc = "Run binary" })

-- Quickfix navigation (compiler errors)
vim.keymap.set("n", "<leader>cn", ":cnext<CR>", { desc = "Next error" })
vim.keymap.set("n", "<leader>cp", ":cprev<CR>", { desc = "Prev error" })

-- Toggle relative numbers quickly
vim.keymap.set("n", "<leader>nr", function()
  vim.opt.relativenumber = not vim.opt.relativenumber:get()
end, { desc = "Toggle relative numbers" })

