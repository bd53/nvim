local opts = { noremap = true, silent = true }

vim.cmd("cnoreabbrev q q!")

vim.keymap.set("n", "<c-a>", "ggVG", opts)
vim.keymap.set("i", "<C-a>", "<Esc>ggVG", opts)

vim.keymap.set({"n", "v"}, "<c-c>", '"+y', opts)

vim.keymap.set("n", "<c-v>", '"+p', opts)
vim.keymap.set("i", "<c-v>", '<Esc>"+pa', opts)

vim.keymap.set("n", "<c-s>", "<cmd>w<CR>", opts)
vim.keymap.set("i", "<c-s>", "<Esc><cmd>w<CR>a", opts)

vim.keymap.set({"n", "i"}, "<c-z>", "<cmd>undo<CR>", opts)

vim.keymap.set("n", "<c-n>", "<cmd>bnext<CR>", opts)
vim.keymap.set("n", "<c-b>", "<cmd>bprevious<CR>", opts)
vim.keymap.set("n", "<c-d>", "<cmd>bdelete<CR>", opts)

vim.keymap.set("n", "<leader>cb", function() require("custom.themes").toggle() end, opts)
vim.keymap.set("n", "<leader>tp", function() require("custom.themes").picker() end, opts)
vim.keymap.set("n", "<c-f>", function() require("custom.finder").toggle() end, opts)
vim.keymap.set("n", "<leader>/", function() require("custom.comments").toggle() end, opts)

vim.keymap.set("n", "<leader>gb", function() require("custom.git").toggle() end, opts)
vim.keymap.set("n", "<leader>gdp", function() require("custom.git").changes() end, opts)
vim.keymap.set("n", "<leader>gh", function() require("custom.git").history() end, opts)
vim.keymap.set("n", "<leader>gc", function() require("custom.git").commit() end, opts)
vim.keymap.set("n", "<leader>gp", function() require("custom.git").push() end, opts)

local term_win = nil
vim.keymap.set("n", "<leader>t", function()
    if term_win and vim.api.nvim_win_is_valid(term_win) then
        vim.api.nvim_win_close(term_win, true)
        term_win = nil
        return
    end
    vim.cmd("vsplit | terminal")
    term_win = vim.api.nvim_get_current_win()
end, opts)
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", opts)

vim.keymap.set("n", "<leader>cd", function()
    vim.ui.input({ prompt = "Change directory: " }, function(input)
        if not input then return end
        vim.cmd.cd(input)
    end)
end, opts)

vim.keymap.set("n", "<c-h>", function()
    local enabled = not vim.lsp.inlay_hint.is_enabled()
    vim.lsp.inlay_hint.enable(enabled)
    vim.notify(("Inlay hints: %s"):format(enabled and "enabled" or "disabled"), vim.log.levels.WARN)
end, opts)
