vim.g.mapleader = " "

vim.opt.number = true
vim.opt.relativenumber = true

vim.g.netrw_banner = 0
vim.g.netrw_winsize = 25
vim.g.netrw_liststyle = 3

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true

vim.opt.wrap = false

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

vim.opt.hlsearch = true
vim.opt.incsearch = true

vim.opt.scrolloff = 8
vim.opt.isfname:append("@-@")
vim.opt.shortmess:append("I")

vim.opt.updatetime = 300

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("config.keymaps")
require("custom")
require("lazy").setup("plugins")

local function reload_custom()
    for module_name, _ in pairs(package.loaded) do
        if module_name:match("^custom") or module_name:match("^config") then
            package.loaded[module_name] = nil
        end
    end
    local ok, err = pcall(function()
        require("config.keymaps")
        require("custom")
    end)
    if not ok then
        vim.notify("Reload failed: " .. tostring(err), vim.log.levels.ERROR)
        return
    end
    vim.notify("Modules reloaded.", vim.log.levels.INFO)
end

vim.keymap.set("n", "<leader>r", reload_custom)
vim.api.nvim_create_user_command("ReloadConfig", reload_custom, {})
