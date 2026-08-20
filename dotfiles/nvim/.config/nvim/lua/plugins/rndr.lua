-- rndr.nvim — render images and 3D models in Neovim buffers
-- Useful for previewing Obsidian vault images without leaving the editor
return {
  "SalarAlo/rndr.nvim",
  build = "make",
  cmd = { "RndrOpen", "RndrClose" },
  keys = {
    { "<leader>ri", "<cmd>RndrOpen<cr>", desc = "Render image/model in buffer" },
    { "<leader>rc", "<cmd>RndrClose<cr>", desc = "Close render" },
  },
  config = function()
    require("rndr").setup()
  end,
}
