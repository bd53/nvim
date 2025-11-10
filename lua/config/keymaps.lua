local opts = { noremap = true, silent = true }

vim.keymap.set("n", "<C-p>", ":Telescope find_files<CR>")
vim.keymap.set("n", "<C-S-f>", ":Telescope live_grep<CR>")
vim.keymap.set("n", "<leader>fb", ":Telescope buffers<CR>")
vim.keymap.set("n", "<C-s>", ":w<CR>", opts)
vim.keymap.set("i", "<C-s>", "<Esc>:w<CR>a", opts)
vim.keymap.set("n", "<C-z>", "u", opts)
vim.keymap.set("i", "<C-z>", "<C-o>u", opts)
vim.keymap.set("n", "<C-y>", "<C-r>", opts)
vim.keymap.set("v", "<C-c>", '"+y', opts)
vim.keymap.set("v", "<C-x>", '"+x', opts)
vim.keymap.set("n", "<C-v>", '"+p', opts)
vim.keymap.set("i", "<C-v>", '<C-r>+', opts)
vim.keymap.set("n", "<C-a>", "ggVG", opts)
vim.keymap.set('n', '<C-B>', ':Ex<CR>', opts)

vim.keymap.set("n", "<leader>ot", ":botright split | resize 15 | term<CR>")

vim.api.nvim_create_autocmd("TermOpen", {
  pattern = "*",
  callback = function()
    vim.opt_local.number = true
    vim.opt_local.relativenumber = true
    vim.opt_local.buflisted = true
    vim.cmd("startinsert")
  end,
})

vim.keymap.set("n", "<leader>ct", function()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buftype == "terminal" then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
end)

vim.keymap.set("n", "<leader>cd", function()
  vim.ui.input({ prompt = "Change directory: " }, function(input)
    if input then
      vim.cmd(("cd %s"):format(input))
    end
  end)
end)
