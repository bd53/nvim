return {
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter.configs").setup({
                ensure_installed = { "c", "cpp", "lua", "rust", "typescript", "tsx", "javascript", "svelte", "vimdoc", "vim" },
                modules = {},
                sync_install = false,
                ignore_install = {},
                auto_install = true,
                highlight = {
                    enable = true,
                    disable = function(_, buf)
                        local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
                        return ok and stats and stats.size > 100 * 1024
                    end
                },
            })
        end,
    },
}
