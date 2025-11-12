local opts = { noremap = true, silent = true }

vim.cmd("cnoreabbrev q q!")

vim.keymap.set("n", "<C-s>", "<cmd>w<CR>", opts)
vim.keymap.set("i", "<C-s>", "<Esc><cmd>w<CR>a", opts)

vim.keymap.set("n", "<C-z>", "<cmd>undo<CR>", opts)
vim.keymap.set("i", "<C-z>", "<C-o>u", opts)

vim.keymap.set("n", "<C-Tab>", "<cmd>bnext<CR>", opts)
vim.keymap.set("n", "<C-S-Tab>", "<cmd>bprevious<CR>", opts)
vim.keymap.set("n", "<leader>q", "<cmd>bdelete<CR>", opts)

vim.keymap.set("n", "<leader>cb", function() require("custom.gruvbox").toggle() end, opts)
vim.keymap.set("n", "<C-p>", function() require("custom.finder").toggle() end, opts)
vim.keymap.set("n", "<leader>/", function() require("custom.comments").toggle() end, opts)

vim.keymap.set("n", "<leader>gb", function() require("custom.git").toggle() end, opts)
vim.keymap.set("n", "<leader>gc", function() require("custom.git").commit() end, opts)
vim.keymap.set("n", "<leader>gp", function() require("custom.git").push() end, opts)

vim.keymap.set("n", "<leader>t", function()
    local term_bufnr
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_get_option(bufnr, "buftype") == "terminal" and vim.api.nvim_buf_is_loaded(bufnr) then
            term_bufnr = bufnr
            break
        end
    end
    if term_bufnr then
        vim.api.nvim_buf_delete(term_bufnr, { force = true })
        return
    end
    vim.cmd("vsplit | terminal")
end, opts)

vim.keymap.set("n", "<leader>cd", function()
    vim.ui.input({ prompt = "Change directory: " }, function(input)
        if not input then return end
        vim.cmd.cd(input)
    end)
end, opts)

vim.keymap.set("n", "<leader>h", function()
    local enabled = not vim.lsp.inlay_hint.is_enabled()
    vim.lsp.inlay_hint.enable(enabled)
    print(("Inlay hints: %s"):format(enabled and "enabled" or "disabled"))
end, opts)
