local Theme = require("custom.themes")

local state = { mode = "N", git_branch = "", git_last_check = 0 }

local colors = {}

local modes = {
    n = "NORMAL",
    i = "INSERT",
    v = "VISUAL",
    V = "V-LINE",
    ["\22"] = "V-BLOCK",
    R = "REPLACE",
    c = "COMMAND",
    t = "TERMINAL",
}

local highlight_groups = {
    { name = "StatuslineNormal", fg = "position_fg" },
    { name = "StatuslineMode", bg = "mode_bg", fg = "mode_fg", bold = true },
    { name = "StatuslineEncoding", fg = "indent_fg" },
    { name = "StatuslineIndent", fg = "indent_fg" },
    { name = "StatuslineSession", fg = "session_fg" },
    { name = "StatuslineBranch", fg = "branch_fg" },
    { name = "StatuslineFilepath", fg = "branch_fg" },
    { name = "StatuslineLSP", fg = "lsp_fg" },
    { name = "StatuslineFiletype", fg = "lsp_fg" },
    { name = "StatuslinePosition", fg = "filetype_fg" },
}

local function get_colors()
    local theme = Theme.current_theme
    local p = Theme.gruvbox_palette
    local t = Theme.terminal_palette
    local s = Theme.solarized_palette
    local v = Theme.vim_palette
    local color_map = {
        gruvbox_dark = {
            mode_bg = p.bright_aqua, mode_fg = p.dark0, branch_fg = p.bright_yellow,
            filetype_fg = p.bright_aqua, position_fg = p.light2, indent_fg = p.bright_purple,
            session_fg = p.bright_yellow, lsp_fg = p.bright_blue, bg = p.dark0,
        },
        gruvbox_light = {
            mode_bg = p.neutral_aqua, mode_fg = p.light0, branch_fg = p.neutral_yellow,
            filetype_fg = p.neutral_aqua, position_fg = p.dark2, indent_fg = p.neutral_purple,
            session_fg = p.neutral_yellow, lsp_fg = p.neutral_blue, bg = p.light0,
        },
        terminal = {
            mode_bg = t.aqua, mode_fg = t.bg0, branch_fg = t.yellow,
            filetype_fg = t.aqua, position_fg = t.fg2, indent_fg = t.purple,
            session_fg = t.yellow, lsp_fg = t.blue, bg = t.bg0,
        },
        solarized_light = {
            mode_bg = s.cyan, mode_fg = s.base3, branch_fg = s.yellow,
            filetype_fg = s.cyan, position_fg = s.base01, indent_fg = s.violet,
            session_fg = s.orange, lsp_fg = s.blue, bg = s.base3,
        },
        vim_classic = {
            mode_bg = v.dark_cyan, mode_fg = v.bg, branch_fg = v.dark_green,
            filetype_fg = v.dark_cyan, position_fg = v.fg_light, indent_fg = v.dark_magenta,
            session_fg = v.dark_yellow, lsp_fg = v.dark_blue, bg = v.bg,
        },
    }
    return color_map[theme] or color_map.gruvbox_dark
end

local function build_components()
    local mode = modes[vim.fn.mode()] or vim.fn.mode():upper()
    state.mode = mode
    local path = vim.fn.expand("%:~:.")
    if path == "" then path = "[No Name]" end
    if vim.bo.modified then path = path .. " [+]" end
    if vim.bo.readonly then path = path .. " []" end
    local ft = vim.bo.filetype
    ft = ft ~= "" and ft or "none"
    local enc = vim.bo.fileencoding
    if enc == "" then enc = vim.o.encoding end
    enc = string.format("%s[%s]", enc, vim.bo.fileformat)
    local shiftwidth = vim.bo.shiftwidth
    local indent = vim.bo.expandtab and string.format("Spaces:%d", shiftwidth) or string.format("Tabs:%d", shiftwidth)
    local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
    local session = string.format(" %s", project_name)
    local now = vim.loop.now()
    if now - state.git_last_check >= 2000 or state.git_branch == "" then
        state.git_last_check = now
        local branch_ok, branch = pcall(function()
            local handle = io.popen("git rev-parse --abbrev-ref HEAD 2>/dev/null")
            if handle then
                local result = handle:read("*a"):gsub("\n", "")
                handle:close()
                return result
            end
            return ""
        end)
        state.git_branch = (branch_ok and branch ~= "") and branch or ""
    end
    local lsp = ""
    local clients = vim.lsp.get_clients({ bufnr = 0 })
    if #clients > 0 then
        local names = {}
        for _, client in ipairs(clients) do
            table.insert(names, client.name)
        end
        lsp = table.concat(names, ",")
    end
    local word_count = ""
    if vim.bo.filetype == "markdown" or vim.bo.filetype == "text" then
        local words = vim.fn.wordcount()
        word_count = string.format("%dW", words.words or 0)
    end
    local size = vim.fn.getfsize(vim.fn.expand("%"))
    local file_size = ""
    if size > 0 then
        if size < 1024 then
            file_size = string.format("%dB", size)
        elseif size < 1024 * 1024 then
            file_size = string.format("%.1fKB", size / 1024)
        else
            file_size = string.format("%.1fMB", size / (1024 * 1024))
        end
    end
    local curr = vim.fn.line(".")
    local total = vim.fn.line("$")
    local pct = math.floor((curr / total) * 100)
    local progress = string.format("%d%%%%", pct)
    local location = string.format("%d:%d", curr, vim.fn.col("."))
    return { mode = mode, encoding = enc, indent = indent, session = session, branch = state.git_branch, filepath = path, lsp = lsp, word_count = word_count, filetype = ft, file_size = file_size, total_lines = string.format("%dL", total), progress = progress, location = location }
end

local function render()
    local c = build_components()
    local function component(highlight, content, prefix)
        if content == "" then return "" end
        prefix = prefix or " "
        return string.format("%%#%s#%s%s %%*", highlight, prefix, content)
    end
    local statusline = component("StatuslineMode", c.mode, " ")
    .. component("StatuslineEncoding", c.encoding)
    .. component("StatuslineIndent", c.indent)
    .. component("StatuslineSession", c.session, "")
    .. component("StatuslineBranch", c.branch, " ")
    .. component("StatuslineFilepath", c.filepath)
    .. (c.lsp ~= "" and component("StatuslineLSP", c.lsp, "  ") or "")
    .. component("StatuslinePosition", c.word_count)
    .. component("StatuslineFiletype", c.filetype)
    .. component("StatuslinePosition", c.file_size)
    .. component("StatuslinePosition", c.total_lines)
    .. component("StatuslinePosition", c.progress)
    .. component("StatuslinePosition", c.location)
    return statusline .. "%#StatuslineNormal#"
end

function _G.statusline_update_colors()
    colors = get_colors()
    for _, hl in ipairs(highlight_groups) do
        local cmd = string.format("hi %s guibg=%s guifg=%s", hl.name, colors[hl.bg or "bg"], colors[hl.fg])
        if hl.bold then cmd = cmd .. " gui=bold" end
        vim.cmd(cmd)
    end
    vim.cmd("redrawstatus")
end

vim.o.laststatus = 2
vim.o.showmode = false

colors = get_colors()
_G.statusline_update_colors()

_G.statusline_render = render
vim.o.statusline = "%!v:lua.statusline_render()"

vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "CursorMoved", "CursorMovedI", "ModeChanged" }, {
    callback = function()
        if vim.v.event.event == "BufEnter" then state.git_last_check = 0 end
        vim.cmd("redrawstatus")
    end,
})

return {}
