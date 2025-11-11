return {
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
      vim.keymap.set("n", "<leader>m", "<cmd>Mason<CR>")
    end
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "rust_analyzer", "ts_ls" },
        automatic_installation = true,
      })
    end
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason.nvim", "williamboman/mason-lspconfig.nvim" },
    config = function()
      vim.lsp.config('rust_analyzer', {
        root_markers = { 'Cargo.toml', '.git' },
        settings = {
          ['rust-analyzer'] = {
            inlayHints = {
              enable = true,
              bindingModeHints = { enable = true },
              chainingHints = { enable = true },
              closingBraceHints = { enable = true, minLines = 10 },
              closureReturnTypeHints = { enable = "always" },
              lifetimeElisionHints = { enable = "always", useParameterNames = true },
              parameterHints = { enable = true },
              typeHints = { enable = true },
            },
          },
        },
      })
      vim.lsp.config('ts_ls', {
        root_markers = { 'package.json', '.git' },
      })
      vim.lsp.enable('rust_analyzer')
      vim.lsp.enable('ts_ls')
    end
  },
}
