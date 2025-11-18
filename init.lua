local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("config.options")
require("config.keymaps")
require("custom")

require("lazy").setup("plugins", {
    rocks = {
        enabled = false,
        hererocks = false,
    },
})

local function reload()
    for name in pairs(package.loaded) do
        if name:match("^custom") or name:match("^config") then
            package.loaded[name] = nil
        end
    end
    local ok, err = pcall(function()
        require("config.options")
        require("config.keymaps")
        require("custom")
    end)
    if not ok then vim.notify("Reload failed: " .. err, vim.log.levels.ERROR) return end
    vim.notify("Config/modules reloaded.", vim.log.levels.INFO)
end

vim.keymap.set("n", "<leader>r", reload)
vim.api.nvim_create_user_command("ReloadConfig", reload, {})

vim.keymap.set("n", "<leader>f", function()
    local start_line = 0
    local end_line = vim.api.nvim_buf_line_count(0) - 1
    vim.api.nvim_buf_call(0, function()
        vim.cmd(string.format("%d,%dnormal! ==", start_line + 1, end_line + 1))
    end)
    vim.cmd("retab")
end)

vim.cmd([[
    highlight Normal guibg=NONE ctermbg=NONE
    highlight NonText guibg=NONE ctermbg=NONE
    highlight SignColumn guibg=NONE ctermbg=NONE
    highlight EndOfBuffer guibg=NONE ctermbg=NONE
]])
