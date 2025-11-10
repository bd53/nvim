return {
  "lewis6991/gitsigns.nvim",
  config = function()
    require('gitsigns').setup({
      signs = {
        add = { hl = 'GitSignsAdd', text = '+' },
        change = { hl = 'GitSignsChange', text = '~' },
        delete = { hl = 'GitSignsDelete', text = '-' },
        topdelete = { hl = 'GitSignsDelete', text = '‾' },
        changedelete = { hl = 'GitSignsChange', text = '~' },
      },
    })
  end
}
