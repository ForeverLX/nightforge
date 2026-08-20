-- obsidian.nvim — Neovim ↔ Obsidian integration
return {
  "epwalsh/obsidian.nvim",
  version = "*",
  lazy = false,
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    workspaces = {
      {
        name = "cr1ms0n-vault",
        path = "/home/ForeverLX/Documents/cr1ms0n-vault",
      },
    },
    daily_notes = {
      folder = "01-Daily-Logs",
      date_format = "%Y-%m-%d",
      template = "tpl-Daily-Log.md",
    },
    templates = {
      subdir = "30-Resources/Templates",
      date_format = "%Y-%m-%d",
    },
  },
  keys = {
    { "<leader>od", "<cmd>ObsidianToday<cr>", desc = "Open daily note" },
    { "<leader>os", "<cmd>ObsidianSearch<cr>", desc = "Search notes" },
    { "<leader>oo", "<cmd>ObsidianOpen<cr>", desc = "Open in Obsidian" },
    { "<leader>on", "<cmd>ObsidianNew<cr>", desc = "New note" },
    { "<leader>ot", "<cmd>ObsidianTemplate<cr>", desc = "Insert template" },
    { "<leader>ob", "<cmd>ObsidianBacklinks<cr>", desc = "Show backlinks" },
    { "<leader>oc", "<cmd>ObsidianToggleCheckbox<cr>", desc = "Toggle checkbox" },
    { "<leader>oe", "<cmd>ObsidianExtractNote<cr>", desc = "Extract to new note" },
  },
}
