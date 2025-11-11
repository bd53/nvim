return {
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
    vim.o.background = "dark"
    vim.cmd.colorscheme("gruvbox")
    vim.cmd("hi NonText guifg=bg")
  end,
}
