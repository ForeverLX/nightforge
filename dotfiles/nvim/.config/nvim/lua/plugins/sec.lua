return {
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = function()
      vim.fn["mkdp#util#install"]()
    end,
  },
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = true,
    keys = {
      { "<A-\\>", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal" },
    },
  },
  { "kdheepak/lazygit.nvim", cmd = { "LazyGit" }, keys = { { "<leader>lg", "<cmd>LazyGit<cr>", desc = "LazyGit" } } },
  { "godlygeek/tabular" },
  { "preservim/vim-markdown", ft = "markdown" },
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
  { "nvim-treesitter/nvim-treesitter-textobjects" },
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons", "MunifTanjim/nui.nvim" },
    keys = { { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "Toggle Neo-tree" } },
  },
}
