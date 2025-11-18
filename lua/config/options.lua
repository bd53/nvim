vim.g.mapleader = " "

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.clipboard = "unnamedplus"
vim.opt.wrap = false
vim.opt.scrolloff = 8
vim.opt.shortmess:append("I")
vim.opt.isfname:append("@-@")
vim.opt.laststatus = 3

vim.g.netrw_banner = 0
vim.g.netrw_winsize = 25
vim.g.netrw_liststyle = 3

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.cmdheight = 1
vim.opt.showcmd = false
vim.opt.updatetime = 200
vim.g.python3_host_prog = "/usr/bin/pynvim-python"
