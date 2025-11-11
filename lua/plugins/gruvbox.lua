return {
  {
    "ellisonleao/gruvbox.nvim",
    config = function()
      require("gruvbox").setup({
        undercurl = true,
        underline = true,
        italic = {
          strings = true,
          emphasis = true,
          comments = true,
          operators = false,
          folds = true,
        },
        contrast = "hard",
      })
      vim.cmd.colorscheme("gruvbox")
    end,
  },
}
