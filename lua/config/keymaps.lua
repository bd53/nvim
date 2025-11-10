local opts = { noremap = true, silent = true }

vim.keymap.set("n", "<C-p>", ":Telescope find_files<CR>")
vim.keymap.set("n", "<C-S-f>", ":Telescope live_grep<CR>")
vim.keymap.set("n", "<leader>fb", ":Telescope buffers<CR>")

vim.keymap.set("n", "<C-s>", ":w<CR>", opts)
vim.keymap.set("i", "<C-s>", "<Esc>:w<CR>a", opts)
vim.keymap.set("n", "<C-z>", "u", opts)
vim.keymap.set("i", "<C-z>", "<C-o>u", opts)
vim.keymap.set("n", "<C-B>", function()
  if vim.bo.filetype == "netrw" then
    vim.cmd("bd")
  else
    vim.cmd("Ex")
  end
end, opts)

vim.keymap.set("n", "<Tab>", ":bnext<CR>", opts)
vim.keymap.set("n", "<S-Tab>", ":bprevious<CR>", opts)

vim.keymap.set("n", "<leader>ot", ":vsplit | term<CR>", opts)
vim.keymap.set("n", "<leader>ct", ":bd!<CR>", opts)

vim.keymap.set("n", "<leader>cd", function()
  vim.ui.input({ prompt = "Change directory: " }, function(input)
    if input then
      vim.cmd(("cd %s"):format(input))
    end
  end)
end)
