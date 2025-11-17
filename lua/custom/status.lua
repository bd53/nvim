local Theme = require("custom.themes")

local state = { mode = "N", git_branch = "", git_last_check = 0 }

local function get_colors()
    local theme = Theme.current_theme
    local color_map = {
        gruvbox_dark = function()
            local p = Theme.gruvbox_palette
            return {
                mode_bg = p.bright_aqua,
                mode_fg = p.dark0,
                branch_fg = p.bright_yellow,
                filetype_fg = p.bright_aqua,
                position_fg = p.light2,
                indent_fg = p.bright_purple,
                session_fg = p.bright_yellow,
                lsp_fg = p.bright_blue,
                bg = p.dark0,
            }
        end,
        gruvbox_light = function()
            local p = Theme.gruvbox_palette
            return {
                mode_bg = p.neutral_aqua,
                mode_fg = p.light0,
                branch_fg = p.neutral_yellow,
                filetype_fg = p.neutral_aqua,
                position_fg = p.dark2,
                indent_fg = p.neutral_purple,
                session_fg = p.neutral_yellow,
                lsp_fg = p.neutral_blue,
                bg = p.light0,
            }
        end,
        terminal = function()
            local p = Theme.terminal_palette
            return {
                mode_bg = p.aqua,
                mode_fg = p.bg0,
                branch_fg = p.yellow,
                filetype_fg = p.aqua,
                position_fg = p.fg2,
                indent_fg = p.purple,
                session_fg = p.yellow,
                lsp_fg = p.blue,
                bg = p.bg0,
            }
        end,
        solarized_light = function()
            local p = Theme.solarized_palette
            return {
                mode_bg = p.cyan,
                mode_fg = p.base3,
                branch_fg = p.yellow,
                filetype_fg = p.cyan,
                position_fg = p.base01,
                indent_fg = p.violet,
                session_fg = p.orange,
                lsp_fg = p.blue,
                bg = p.base3,
            }
        end,
        vim_classic = function()
            local p = Theme.vim_palette
            return {
                mode_bg = p.dark_cyan,
                mode_fg = p.bg,
                branch_fg = p.dark_green,
                filetype_fg = p.dark_cyan,
                position_fg = p.fg_light,
                indent_fg = p.dark_magenta,
                session_fg = p.dark_yellow,
                lsp_fg = p.dark_blue,
                bg = p.bg,
            }
        end,
    }
    local color_fn = color_map[theme] or color_map.gruvbox_dark
    return color_fn()
end

local colors = get_colors()

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

local function get_mode()
    local mode = vim.fn.mode()
    state.mode = modes[mode] or mode:upper()
    return state.mode
end

local function get_filepath()
    local path = vim.fn.expand("%:~:.")
    if path == "" then return "[No Name]" end
    local indicators = ""
    if vim.bo.modified then indicators = indicators .. " [+]" end
    if vim.bo.readonly then indicators = indicators .. " []" end
    return path .. indicators
end

local function get_git_info()
    local now = vim.loop.now()
    if now - state.git_last_check < 2000 and state.git_branch ~= "" then return state.git_branch end
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
    return state.git_branch
end

local function get_filetype()
    local ft = vim.bo.filetype
    return ft ~= "" and ft or "none"
end

local function get_encoding()
    local enc = vim.bo.fileencoding
    if enc == "" then enc = vim.o.encoding end
    local format = vim.bo.fileformat
    return string.format("%s[%s]", enc, format)
end

local function get_progress()
    local curr = vim.fn.line(".")
    local total = vim.fn.line("$")
    local pct = math.floor((curr / total) * 100)
    return string.format("%d%%%%", pct)
end

local function get_location()
    return string.format("%d:%d", vim.fn.line("."), vim.fn.col("."))
end

local function get_word_count()
    if vim.bo.filetype == "markdown" or vim.bo.filetype == "text" then
        local words = vim.fn.wordcount()
        return string.format("%dW", words.words or 0)
    end
    return ""
end

local function get_file_size()
    local size = vim.fn.getfsize(vim.fn.expand("%"))
    if size <= 0 then return "" end
    if size < 1024 then return string.format("%dB", size) end
    if size < 1024 * 1024 then return string.format("%.1fKB", size / 1024) end
    return string.format("%.1fMB", size / (1024 * 1024))
end

local function get_lsp_status()
    local clients = vim.lsp.get_clients({ bufnr = 0 })
    if #clients == 0 then return "" end
    local names = {}
    for _, client in ipairs(clients) do
        table.insert(names, client.name)
    end
    return table.concat(names, ",")
end

local function get_indent_info()
    local expandtab = vim.bo.expandtab
    local shiftwidth = vim.bo.shiftwidth
    if expandtab then return string.format("Spaces:%d", shiftwidth) end
    return string.format("Tabs:%d", shiftwidth)
end

local function get_session_info()
    local cwd = vim.fn.getcwd()
    local project_name = vim.fn.fnamemodify(cwd, ":t")
    return string.format(" %s", project_name)
end

local function component(highlight, content, prefix)
    if content == "" then return "" end
    prefix = prefix or " "
    return string.format("%%#%s#%s%s %%*", highlight, prefix, content)
end

local components = {
    mode = function()
        return component("StatuslineMode", get_mode(), " ")
    end,
    encoding = function()
        return component("StatuslineEncoding", get_encoding())
    end,
    indent = function()
        return component("StatuslineIndent", get_indent_info())
    end,
    session = function()
        return component("StatuslineSession", get_session_info(), "")
    end,
    filepath = function()
        return component("StatuslineFilepath", get_filepath())
    end,
    branch = function()
        return component("StatuslineBranch", get_git_info(), " ")
    end,
    lsp = function()
        local lsp = get_lsp_status()
        return lsp ~= "" and component("StatuslineLSP", lsp, "  ") or ""
    end,
    word_count = function()
        return component("StatuslinePosition", get_word_count())
    end,
    filetype = function()
        return component("StatuslineFiletype", get_filetype())
    end,
    file_size = function()
        return component("StatuslinePosition", get_file_size())
    end,
    total_lines = function()
        return component("StatuslinePosition", string.format("%dL", vim.fn.line("$")))
    end,
    progress = function()
        return component("StatuslinePosition", get_progress())
    end,
    location = function()
        return component("StatuslinePosition", get_location())
    end,
}

local function render()
    local statusline = components.mode()
    .. components.encoding() 
    .. components.indent() 
    .. components.session() 
    .. components.branch() 
    .. components.filepath() 
    .. components.lsp() 
    .. components.word_count() 
    .. components.filetype() 
    .. components.file_size() 
    .. components.total_lines() 
    .. components.progress() 
    .. components.location()
    return statusline .. "%#StatuslineNormal#"
end

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

local function setup_highlights()
    for _, hl in ipairs(highlight_groups) do
        local cmd = string.format("hi %s guibg=%s guifg=%s", hl.name, colors[hl.bg or "bg"], colors[hl.fg])
        if hl.bold then cmd = cmd .. " gui=bold" end
        vim.cmd(cmd)
    end
end

function _G.statusline_update_colors()
    colors = get_colors()
    setup_highlights()
    vim.cmd("redrawstatus")
end

vim.o.laststatus = 2
vim.o.showmode = false

setup_highlights()

_G.statusline_render = render
vim.o.statusline = "%!v:lua.statusline_render()"

vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "CursorMoved", "CursorMovedI", "ModeChanged" }, {
    callback = function()
        if vim.v.event.event == "BufEnter" then state.git_last_check = 0 end
        vim.cmd("redrawstatus")
    end,
})

return {}
