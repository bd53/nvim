local Window = require("custom.window")
local Theme = {}

-- https://github.com/ellisonleao/gruvbox.nvim/blob/main/lua/gruvbox.lua#L74
---@class GruvboxPalette
Theme.gruvbox_palette = {
    dark0_hard = "#1d2021",
    dark0 = "#282828",
    dark0_soft = "#32302f",
    dark1 = "#3c3836",
    dark2 = "#504945",
    dark3 = "#665c54",
    dark4 = "#7c6f64",
    light0_hard = "#f9f5d7",
    light0 = "#fbf1c7",
    light0_soft = "#f2e5bc",
    light1 = "#ebdbb2",
    light2 = "#d5c4a1",
    light3 = "#bdae93",
    light4 = "#a89984",
    bright_red = "#fb4934",
    bright_green = "#b8bb26",
    bright_yellow = "#fabd2f",
    bright_blue = "#83a598",
    bright_purple = "#d3869b",
    bright_aqua = "#8ec07c",
    bright_orange = "#fe8019",
    neutral_red = "#cc241d",
    neutral_green = "#98971a",
    neutral_yellow = "#d79921",
    neutral_blue = "#458588",
    neutral_purple = "#b16286",
    neutral_aqua = "#689d6a",
    neutral_orange = "#d65d0e",
    faded_red = "#9d0006",
    faded_green = "#79740e",
    faded_yellow = "#b57614",
    faded_blue = "#076678",
    faded_purple = "#8f3f71",
    faded_aqua = "#427b58",
    faded_orange = "#af3a03",
    gray = "#928374",
}

---@class TerminalPalette
Theme.terminal_palette = {
    bg0 = "#000000",
    bg1 = "#1a1a1a",
    bg2 = "#262626",
    bg3 = "#333333",
    bg4 = "#4d4d4d",
    fg0 = "#ffffff",
    fg1 = "#e6e6e6",
    fg2 = "#cccccc",
    fg3 = "#b3b3b3",
    fg4 = "#999999",
    red = "#ff5555",
    green = "#50fa7b",
    yellow = "#f1fa8c",
    blue = "#8be9fd",
    purple = "#bd93f9",
    aqua = "#8be9fd",
    orange = "#ffb86c",
    gray = "#6272a4",
}

---@class SolarizedPalette
Theme.solarized_palette = {
    base03 = "#002b36",
    base02 = "#073642",
    base01 = "#586e75",
    base00 = "#657b83",
    base0 = "#839496",
    base1 = "#93a1a1",
    base2 = "#eee8d5",
    base3 = "#fdf6e3",
    yellow = "#b58900",
    orange = "#cb4b16",
    red = "#dc322f",
    magenta = "#d33682",
    violet = "#6c71c4",
    blue = "#268bd2",
    cyan = "#2aa198",
    green = "#859900",
}

---@class VimPalette
Theme.vim_palette = {
    bg = "#ffffff",
    bg_dark = "#e4e4e4",
    bg_darker = "#d0d0d0",
    bg_darkest = "#bcbcbc",
    fg = "#000000",
    fg_light = "#4a4a4a",
    fg_lighter = "#767676",
    fg_lightest = "#9e9e9e",
    red = "#ff0000",
    green = "#00ff00",
    yellow = "#ffff00",
    blue = "#0000ff",
    magenta = "#ff00ff",
    cyan = "#00ffff",
    dark_red = "#800000",
    dark_green = "#008000",
    dark_yellow = "#808000",
    dark_blue = "#000080",
    dark_magenta = "#800080",
    dark_cyan = "#008080",
    gray = "#808080",
}

Theme.theme_order = { "gruvbox_dark", "gruvbox_light", "terminal", "solarized_light", "vim_classic" }
Theme.current_theme = "gruvbox_dark"
Theme.picker_state = { buf = nil, win = nil, is_open = false }

local theme_cache_path = vim.fn.stdpath("config") .. "/theme.txt"

local function save_theme()
    local file = io.open(theme_cache_path, "w")
    if file then
        file:write(Theme.current_theme)
        file:close()
    end
end

local function load_theme()
    local file = io.open(theme_cache_path, "r")
    if file then
        local saved_theme = file:read("*l")
        file:close()
        for _, theme in ipairs(Theme.theme_order) do
            if theme == saved_theme then
                Theme.current_theme = saved_theme
                return
            end
        end
    end
end

local function get_gruvbox_colors(mode)
    local p = Theme.gruvbox_palette
    if mode == "dark" then
        return {
            bg0 = p.dark0,
            bg1 = p.dark1,
            bg2 = p.dark2,
            bg3 = p.dark3,
            bg4 = p.dark4,
            fg0 = p.light0,
            fg1 = p.light1,
            fg2 = p.light2,
            fg3 = p.light3,
            fg4 = p.light4,
            red = p.bright_red,
            green = p.bright_green,
            yellow = p.bright_yellow,
            blue = p.bright_blue,
            purple = p.bright_purple,
            aqua = p.bright_aqua,
            orange = p.bright_orange,
            gray = p.gray,
        }
    end
    return {
        bg0 = p.light0,
        bg1 = p.light1,
        bg2 = p.light2,
        bg3 = p.light3,
        bg4 = p.light4,
        fg0 = p.dark0,
        fg1 = p.dark1,
        fg2 = p.dark2,
        fg3 = p.dark3,
        fg4 = p.dark4,
        red = p.neutral_red,
        green = p.neutral_green,
        yellow = p.neutral_yellow,
        blue = p.neutral_blue,
        purple = p.neutral_purple,
        aqua = p.neutral_aqua,
        orange = p.neutral_orange,
        gray = p.gray,
    }
end

local function get_terminal_colors()
    local p = Theme.terminal_palette
    return {
        bg0 = p.bg0,
        bg1 = p.bg1,
        bg2 = p.bg2,
        bg3 = p.bg3,
        bg4 = p.bg4,
        fg0 = p.fg0,
        fg1 = p.fg1,
        fg2 = p.fg2,
        fg3 = p.fg3,
        fg4 = p.fg4,
        red = p.red,
        green = p.green,
        yellow = p.yellow,
        blue = p.blue,
        purple = p.purple,
        aqua = p.aqua,
        orange = p.orange,
        gray = p.gray,
    }
end

local function get_solarized_light_colors()
    local p = Theme.solarized_palette
    return {
        bg0 = p.base3,
        bg1 = p.base2,
        bg2 = p.base2,
        bg3 = p.base1,
        bg4 = p.base0,
        fg0 = p.base03,
        fg1 = p.base02,
        fg2 = p.base01,
        fg3 = p.base00,
        fg4 = p.base0,
        red = p.red,
        green = p.green,
        yellow = p.yellow,
        blue = p.blue,
        purple = p.violet,
        aqua = p.cyan,
        orange = p.orange,
        gray = p.base1,
    }
end

local function get_vim_classic_colors()
    local p = Theme.vim_palette
    return {
        bg0 = p.bg,
        bg1 = p.bg_dark,
        bg2 = p.bg_darker,
        bg3 = p.bg_darkest,
        bg4 = p.fg_lightest,
        fg0 = p.fg,
        fg1 = p.fg_light,
        fg2 = p.fg_light,
        fg3 = p.fg_lighter,
        fg4 = p.fg_lightest,
        red = p.dark_red,
        green = p.dark_green,
        yellow = p.dark_yellow,
        blue = p.dark_blue,
        purple = p.dark_magenta,
        aqua = p.dark_cyan,
        orange = p.dark_red,
        gray = p.gray,
    }
end

local function get_colors()
    if Theme.current_theme == "terminal" then
        return get_terminal_colors()
    elseif Theme.current_theme == "gruvbox_dark" then
        return get_gruvbox_colors("dark")
    elseif Theme.current_theme == "gruvbox_light" then
        return get_gruvbox_colors("light")
    elseif Theme.current_theme == "solarized_light" then
        return get_solarized_light_colors()
    elseif Theme.current_theme == "vim_classic" then
        return get_vim_classic_colors()
    end
    return get_gruvbox_colors("dark")
end

local function setup_highlights()
    local c = get_colors()
    local set = vim.api.nvim_set_hl
    if Theme.current_theme == "gruvbox_light" or Theme.current_theme == "solarized_light" or Theme.current_theme == "vim_classic" then
        vim.cmd("set background=light")
    else
        vim.cmd("set background=dark")
    end
    set(0, "Normal", { fg = c.fg1, bg = c.bg0 })
    set(0, "NormalFloat", { fg = c.fg1, bg = c.bg1 })
    set(0, "NormalNC", { fg = c.fg1, bg = c.bg0 })
    set(0, "CursorLine", { bg = c.bg1 })
    set(0, "CursorColumn", { bg = c.bg1 })
    set(0, "ColorColumn", { bg = c.bg1 })
    set(0, "Conceal", { fg = c.blue })
    set(0, "Cursor", { reverse = true })
    set(0, "lCursor", { reverse = true })
    set(0, "CursorIM", { reverse = true })
    set(0, "CursorLineNr", { fg = c.yellow, bold = true })
    set(0, "LineNr", { fg = c.bg4 })
    set(0, "SignColumn", { bg = c.bg0 })
    set(0, "VertSplit", { fg = c.bg2, bg = c.bg0 })
    set(0, "WinSeparator", { fg = c.bg2, bg = c.bg0 })
    set(0, "Folded", { fg = c.gray, bg = c.bg1, italic = true })
    set(0, "FoldColumn", { fg = c.gray, bg = c.bg0 })
    set(0, "Search", { fg = c.bg0, bg = c.yellow })
    set(0, "IncSearch", { fg = c.bg0, bg = c.orange })
    set(0, "CurSearch", { fg = c.bg0, bg = c.orange })
    set(0, "Visual", { bg = c.bg3 })
    set(0, "VisualNOS", { bg = c.bg3 })
    set(0, "Comment", { fg = c.gray, italic = true })
    set(0, "Constant", { fg = c.purple })
    set(0, "String", { fg = c.green })
    set(0, "Character", { fg = c.purple })
    set(0, "Number", { fg = c.purple })
    set(0, "Boolean", { fg = c.purple })
    set(0, "Float", { fg = c.purple })
    set(0, "Identifier", { fg = c.blue })
    set(0, "Function", { fg = c.green, bold = true })
    set(0, "Statement", { fg = c.red })
    set(0, "Conditional", { fg = c.red })
    set(0, "Repeat", { fg = c.red })
    set(0, "Label", { fg = c.red })
    set(0, "Operator", { fg = c.orange })
    set(0, "Keyword", { fg = c.red })
    set(0, "Exception", { fg = c.red })
    set(0, "PreProc", { fg = c.aqua })
    set(0, "Include", { fg = c.aqua })
    set(0, "Define", { fg = c.aqua })
    set(0, "Macro", { fg = c.aqua })
    set(0, "PreCondit", { fg = c.aqua })
    set(0, "Type", { fg = c.yellow })
    set(0, "StorageClass", { fg = c.orange })
    set(0, "Structure", { fg = c.aqua })
    set(0, "Typedef", { fg = c.yellow })
    set(0, "Special", { fg = c.orange })
    set(0, "SpecialChar", { fg = c.red })
    set(0, "Tag", { fg = c.orange })
    set(0, "Delimiter", { fg = c.fg1 })
    set(0, "SpecialComment", { fg = c.gray, italic = true })
    set(0, "Debug", { fg = c.red })
    set(0, "Underlined", { fg = c.blue, underline = true })
    set(0, "Ignore", { fg = c.bg4 })
    set(0, "Error", { fg = c.red, bold = true })
    set(0, "Todo", { fg = c.bg0, bg = c.yellow, bold = true })
    set(0, "@variable", { fg = c.fg1 })
    set(0, "@variable.builtin", { fg = c.orange })
    set(0, "@variable.parameter", { fg = c.blue })
    set(0, "@variable.member", { fg = c.blue })
    set(0, "@constant", { fg = c.purple })
    set(0, "@constant.builtin", { fg = c.purple })
    set(0, "@module", { fg = c.yellow })
    set(0, "@string", { fg = c.green })
    set(0, "@string.escape", { fg = c.red })
    set(0, "@string.special", { fg = c.orange })
    set(0, "@character", { fg = c.purple })
    set(0, "@number", { fg = c.purple })
    set(0, "@boolean", { fg = c.purple })
    set(0, "@number.float", { fg = c.purple })
    set(0, "@function", { fg = c.green, bold = true })
    set(0, "@function.builtin", { fg = c.orange, bold = true })
    set(0, "@function.call", { fg = c.green })
    set(0, "@function.macro", { fg = c.aqua })
    set(0, "@method", { fg = c.green, bold = true })
    set(0, "@method.call", { fg = c.green })
    set(0, "@constructor", { fg = c.yellow })
    set(0, "@parameter", { fg = c.blue })
    set(0, "@keyword", { fg = c.red })
    set(0, "@keyword.function", { fg = c.red })
    set(0, "@keyword.operator", { fg = c.red })
    set(0, "@keyword.return", { fg = c.red })
    set(0, "@conditional", { fg = c.red })
    set(0, "@repeat", { fg = c.red })
    set(0, "@label", { fg = c.orange })
    set(0, "@operator", { fg = c.orange })
    set(0, "@exception", { fg = c.red })
    set(0, "@type", { fg = c.yellow })
    set(0, "@type.builtin", { fg = c.yellow })
    set(0, "@type.qualifier", { fg = c.red })
    set(0, "@structure", { fg = c.aqua })
    set(0, "@include", { fg = c.aqua })
    set(0, "@attribute", { fg = c.aqua })
    set(0, "@property", { fg = c.blue })
    set(0, "@field", { fg = c.blue })
    set(0, "@tag", { fg = c.orange })
    set(0, "@tag.attribute", { fg = c.green })
    set(0, "@tag.delimiter", { fg = c.fg4 })
    set(0, "@punctuation.delimiter", { fg = c.fg4 })
    set(0, "@punctuation.bracket", { fg = c.fg1 })
    set(0, "@punctuation.special", { fg = c.red })
    set(0, "@comment", { fg = c.gray, italic = true })
    set(0, "LspReferenceText", { bg = c.bg2 })
    set(0, "LspReferenceRead", { bg = c.bg2 })
    set(0, "LspReferenceWrite", { bg = c.bg2 })
    set(0, "LspInlayHint", { fg = c.bg4, bg = c.bg1, italic = true })
    set(0, "DiagnosticError", { fg = c.red })
    set(0, "DiagnosticWarn", { fg = c.yellow })
    set(0, "DiagnosticInfo", { fg = c.blue })
    set(0, "DiagnosticHint", { fg = c.aqua })
    set(0, "DiagnosticUnderlineError", { undercurl = true, sp = c.red })
    set(0, "DiagnosticUnderlineWarn", { undercurl = true, sp = c.yellow })
    set(0, "DiagnosticUnderlineInfo", { undercurl = true, sp = c.blue })
    set(0, "DiagnosticUnderlineHint", { undercurl = true, sp = c.aqua })
    set(0, "LspSignatureActiveParameter", { fg = c.orange, bold = true })
    set(0, "DiffAdd", { fg = c.green, bg = c.bg1 })
    set(0, "DiffChange", { fg = c.aqua, bg = c.bg1 })
    set(0, "DiffDelete", { fg = c.red, bg = c.bg1 })
    set(0, "DiffText", { fg = c.yellow, bg = c.bg2 })
    set(0, "diffAdded", { fg = c.green })
    set(0, "diffRemoved", { fg = c.red })
    set(0, "diffChanged", { fg = c.aqua })
    set(0, "diffFile", { fg = c.orange })
    set(0, "diffNewFile", { fg = c.yellow })
    set(0, "diffLine", { fg = c.blue })
    set(0, "Pmenu", { fg = c.fg1, bg = c.bg2 })
    set(0, "PmenuSel", { fg = c.bg0, bg = c.blue })
    set(0, "PmenuSbar", { bg = c.bg2 })
    set(0, "PmenuThumb", { bg = c.bg4 })
    set(0, "StatusLine", { fg = c.fg1, bg = c.bg2 })
    set(0, "StatusLineNC", { fg = c.bg4, bg = c.bg1 })
    set(0, "TabLine", { fg = c.bg4, bg = c.bg1 })
    set(0, "TabLineFill", { fg = c.bg4, bg = c.bg1 })
    set(0, "TabLineSel", { fg = c.green, bg = c.bg2 })
    set(0, "ErrorMsg", { fg = c.red, bold = true })
    set(0, "WarningMsg", { fg = c.yellow, bold = true })
    set(0, "MoreMsg", { fg = c.yellow, bold = true })
    set(0, "ModeMsg", { fg = c.yellow, bold = true })
    set(0, "Question", { fg = c.orange, bold = true })
    set(0, "Directory", { fg = c.green, bold = true })
    set(0, "Title", { fg = c.green, bold = true })
    set(0, "SpecialKey", { fg = c.bg4 })
    set(0, "NonText", { fg = c.bg2 })
    set(0, "EndOfBuffer", { fg = c.bg0 })
    set(0, "MatchParen", { fg = c.orange, bold = true })
    set(0, "Whitespace", { fg = c.bg2 })
    set(0, "WildMenu", { fg = c.blue, bg = c.bg2, bold = true })
    set(0, "QuickFixLine", { fg = c.bg0, bg = c.yellow })
    set(0, "SpellBad", { undercurl = true, sp = c.red })
    set(0, "SpellCap", { undercurl = true, sp = c.blue })
    set(0, "SpellLocal", { undercurl = true, sp = c.aqua })
    set(0, "SpellRare", { undercurl = true, sp = c.purple })
    set(0, "netrwDir", { fg = c.aqua })
    set(0, "netrwClassify", { fg = c.aqua })
    set(0, "netrwLink", { fg = c.gray })
    set(0, "netrwSymLink", { fg = c.fg1 })
    set(0, "netrwExe", { fg = c.yellow })
    set(0, "netrwComment", { fg = c.gray })
    set(0, "netrwList", { fg = c.blue })
    set(0, "netrwHelpCmd", { fg = c.aqua })
    set(0, "netrwCmdSep", { fg = c.fg3 })
    set(0, "netrwVersion", { fg = c.green })
end

function Theme.toggle()
    local current_index = 1
    for i, theme in ipairs(Theme.theme_order) do
        if theme == Theme.current_theme then
            current_index = i
            break
        end
    end
    local next_index = (current_index % #Theme.theme_order) + 1
    Theme.current_theme = Theme.theme_order[next_index]
    setup_highlights()
    save_theme()
    if _G.statusline_update_colors then _G.statusline_update_colors() end
    vim.notify(("Theme: %s"):format(Theme.current_theme), vim.log.levels.WARN)
end

local function apply_theme(theme_name)
    if theme_name then
        Theme.current_theme = theme_name
        setup_highlights()
        save_theme()
        if _G.statusline_update_colors then _G.statusline_update_colors() end
        vim.notify(("Theme: %s"):format(Theme.current_theme), vim.log.levels.WARN)
    end
end

local function close_picker()
    if Theme.picker_state.is_open then
        Window.safe_close_window(Theme.picker_state.win)
        Window.safe_delete_buffer(Theme.picker_state.buf)
        Theme.picker_state = { buf = nil, win = nil, is_open = false }
    end
end

function Theme.picker()
    if Theme.picker_state.is_open then close_picker() return end
    local display_names = {
        gruvbox_dark = "Gruvbox Dark",
        gruvbox_light = "Gruvbox Light",
        terminal = "Terminal",
        solarized_light = "Solarized Light",
        vim_classic = "Vim Classic"
    }
    local items = {}
    for _, theme in ipairs(Theme.theme_order) do
        local display_name = display_names[theme] or theme
        local marker = (theme == Theme.current_theme) and " ✓" or ""
        table.insert(items, display_name .. marker)
    end
    local buf, win = Window.create_select({
        items = items,
        title = " Options ",
        width = 30,
        callback = function(selected)
            close_picker()
            if selected then
                local clean_name = selected:gsub(" ✓$", "")
                for theme_key, display_name in pairs(display_names) do
                    if display_name == clean_name then
                        apply_theme(theme_key)
                        break
                    end
                end
            end
        end
    })
    Theme.picker_state = { buf = buf, win = win, is_open = true }
    vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(win),
        once = true,
        callback = function()
            Theme.picker_state = { buf = nil, win = nil, is_open = false }
        end
    })
end

load_theme()
setup_highlights()

return Theme
