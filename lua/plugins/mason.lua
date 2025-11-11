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
        ensure_installed = { "clangd", "lua_ls", "rust_analyzer", "ts_ls", "svelte" },
        automatic_installation = true,
      })
    end
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason.nvim", "williamboman/mason-lspconfig.nvim" },
    config = function()
      vim.lsp.config("clangd", {
        root_markers = { "CMakeLists.txt", "Makefile", ".git" },
      })
      vim.lsp.config("lua_ls", {
        root_markers = { ".luarc.json", ".git" },
      })
      vim.lsp.config("rust_analyzer", {
        root_markers = { "Cargo.toml", ".git" },
        settings = {
          ["rust-analyzer"] = {
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
      vim.lsp.config("ts_ls", {
        root_markers = { "package.json", ".git" },
      })
      vim.lsp.config("svelte", {
        root_markers = { "svelte.config.js", "package.json", ".git" },
      })
      vim.lsp.enable("clangd")
      vim.lsp.enable("lua_ls")
      vim.lsp.enable("rust_analyzer")
      vim.lsp.enable("ts_ls")
      vim.lsp.enable("svelte")
    end
  },
}
