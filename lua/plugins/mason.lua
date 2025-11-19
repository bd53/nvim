return {
    {
        "williamboman/mason.nvim",
        config = function()
            require("mason").setup()
        end
    },
    {
        "williamboman/mason-lspconfig.nvim",
        dependencies = { "williamboman/mason.nvim" },
        config = function()
            require("mason-lspconfig").setup({
                ensure_installed = { "clangd", "csharp_ls", "lua_ls", "rust_analyzer", "ts_ls", "svelte" },
                automatic_installation = true,
            })
        end
    },
    {
        "neovim/nvim-lspconfig",
        dependencies = { "williamboman/mason.nvim", "williamboman/mason-lspconfig.nvim" },
        config = function()
            vim.lsp.config("clangd", {
                root_markers = { "CMakeLists.txt", "Makefile", "justfile", ".git" },
                filetypes = { "c", "cpp" },
            })
            vim.lsp.config("csharp_ls", {
                root_markers = { "*.csproj", "*.sln", ".git" },
                filetypes = { "cs" },
            })
            vim.lsp.config("lua_ls", {
                root_markers = { ".luarc.json", ".git" },
                filetypes = { "lua" },
                settings = {
                    Lua = {
                        runtime = {
                            version = "LuaJIT",
                        },
                        diagnostics = {
                            globals = { "vim" },
                        },
                    },
                },
            })
            vim.lsp.config("rust_analyzer", {
                root_dir = { "Cargo.toml", "Makefile", "justfile", ".git" },
                filetypes = { "rust" },
            })
            vim.lsp.config("ts_ls", {
                root_markers = { "package.json", ".git" },
                filetypes = { "typescript", "javascript" },
            })
            vim.lsp.config("svelte", {
                root_markers = { "svelte.config.js", "package.json", ".git" },
                filetypes = { "svelte" },
            })
            vim.lsp.enable("clangd")
            vim.lsp.enable("csharp_ls")
            vim.lsp.enable("lua_ls")
            vim.lsp.enable("rust_analyzer")
            vim.lsp.enable("ts_ls")
            vim.lsp.enable("svelte")
        end
    },
}
