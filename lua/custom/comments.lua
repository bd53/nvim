local Comments = {}

local Config = {
    keywords = {
        { word = "@todo", color = "#8b963b" },
        { word = "@fix", color = "#2e7da1" },
        { word = "@ignore", color = "#b63f3b" },
    },
    comment_strings = {
        rs = "//",
        cpp = "//",
        ts = "//",
        js = "//",
        lua = "--",
    },
}

local function setup_highlights()
    for _, kw in ipairs(Config.keywords) do
        local group_name = "CommentKeyword" .. kw.word:gsub("@", "")
        vim.cmd(string.format("highlight %s guifg=%s gui=bold", group_name, kw.color))
    end
    local ft = vim.bo.filetype
    local comment_str = Config.comment_strings[ft] or "//"
    for _, kw in ipairs(Config.keywords) do
        local hl_group = "CommentKeyword" .. kw.word:gsub("@", "")
        local pattern = vim.pesc(comment_str) .. ".*" .. vim.pesc(kw.word)
        vim.fn.matchadd(hl_group, pattern)
    end
    vim.keymap.set("n", "<leader>f", function()
        local start_line = 0
        local end_line = vim.api.nvim_buf_line_count(0) - 1
        vim.api.nvim_buf_call(0, function()
            vim.cmd(string.format("%d,%dnormal! ==", start_line + 1, end_line + 1))
        end)
        vim.cmd("retab")
    end)
end

function Comments.toggle()
    local ft = vim.bo.filetype
    local comment_str = Config.comment_strings[ft] or "//"
    local line = vim.api.nvim_get_current_line()
    local pattern = "^%s*" .. vim.pesc(comment_str)
    if line:match(pattern) then
        line = line:gsub(pattern .. "%s?", "")
        vim.api.nvim_set_current_line(line)
        return
    end
    vim.api.nvim_set_current_line(comment_str .. " " .. line)
end

setup_highlights()

return Comments
