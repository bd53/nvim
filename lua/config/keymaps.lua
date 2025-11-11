local opts = { noremap = true, silent = true }

vim.keymap.set("n", "<C-p>", ":Telescope find_files<CR>", opts)
vim.keymap.set("n", "<C-S-f>", ":Telescope live_grep<CR>", opts)
vim.keymap.set("n", "<leader>fb", ":Telescope buffers<CR>", opts)

vim.keymap.set("n", "<C-s>", vim.cmd.w, opts)
vim.keymap.set("i", "<C-s>", "<Esc>:w<CR>a", opts)

vim.keymap.set("n", "<C-z>", vim.cmd.undo, opts)
vim.keymap.set("i", "<C-z>", "<C-o>u", opts)

vim.keymap.set("n", "<C-B>", function()
  if vim.bo.filetype == "netrw" then return vim.cmd("bd") end
  vim.cmd("Ex")
end, opts)

vim.keymap.set("n", "<Tab>", vim.cmd.bnext, opts)
vim.keymap.set("n", "<S-Tab>", vim.cmd.bprevious, opts)

vim.keymap.set("n", "<leader>ot", ":vsplit | term<CR>", opts)
vim.keymap.set("n", "<leader>ct", ":bd!<CR>", opts)

vim.keymap.set("n", "<leader>cd", function()
  vim.ui.input({ prompt = "Change directory: " }, function(input)
    if not input then return end
    vim.cmd.cd(input)
  end)
end, opts)

vim.keymap.set("n", "<leader>cb", function()
  vim.o.background = vim.o.background == "light" and "dark" or "light"
  vim.cmd("hi NonText guifg=bg")
end)

vim.keymap.set("n", "<leader>ih", function()
  local enabled = not vim.lsp.inlay_hint.is_enabled()
  vim.lsp.inlay_hint.enable(enabled)
  print(("Inlay hints: %s"):format(enabled and "enabled" or "disabled"))
end, opts)
