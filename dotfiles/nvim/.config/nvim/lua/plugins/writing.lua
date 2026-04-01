return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    ft = { "markdown" },
    opts = {
      render_modes = { "n", "c" },
      anti_conceal = { enabled = true },
      heading = {
        enabled = true,
        sign = false,
        icons = { "󰉫 ", "󰉬 ", "󰉭 ", "󰉮 ", "󰉯 ", "󰉰 " },
      },
      code = {
        enabled = true,
        sign = false,
        style = "full",
        border = "thin",
      },
      checkbox = {
        enabled = true,
        unchecked = { icon = "󰄱 " },
        checked = { icon = "󰄲 " },
      },
    },
    keys = {
      {
        "<leader>rm",
        "<cmd>RenderMarkdown toggle<cr>",
        desc = "Toggle markdown render",
      },
    },
  },
  {
    "folke/twilight.nvim",
    cmd = { "Twilight", "TwilightEnable", "TwilightDisable" },
    keys = {
      {
        "<leader>tw",
        "<cmd>Twilight<cr>",
        desc = "Toggle Twilight focus",
      },
    },
    opts = {
      dimming = {
        alpha = 0.25,
        inactive = false,
      },
      context = 15,
      treesitter = true,
    },
  },
}
