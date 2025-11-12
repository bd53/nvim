local Gruvbox = require("custom.gruvbox")

local function get_colors()
  local p = Gruvbox.palette
  if Gruvbox.current_mode == "dark" then
    return {
      mode_bg = p.bright_aqua,
      mode_fg = p.dark0,
      branch_fg = p.bright_yellow,
      filepath_fg = p.bright_blue,
      filetype_fg = p.bright_aqua,
      position_fg = p.light2,
      encoding_fg = p.bright_aqua,
      indent_fg = p.bright_purple,
      session_fg = p.bright_yellow,
      lsp_fg = p.bright_blue,
      bg = p.dark0,
    }
  end
  return {
    mode_bg = p.neutral_aqua,
    mode_fg = p.light0,
    branch_fg = p.neutral_yellow,
    filepath_fg = p.neutral_blue,
    filetype_fg = p.neutral_aqua,
    position_fg = p.dark2,
    encoding_fg = p.neutral_aqua,
    indent_fg = p.neutral_purple,
    session_fg = p.neutral_yellow,
    lsp_fg = p.neutral_blue,
    bg = p.light0,
  }
end

local colors = get_colors()

local State = {
  mode = "N",
  git_branch = "",
  git_last_check = 0,
}

local function get_mode()
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
  local mode = vim.fn.mode()
  State.mode = modes[mode] or mode:upper()
  return State.mode
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
  if now - State.git_last_check < 2000 and State.git_branch ~= "" then return State.git_branch end
  State.git_last_check = now
  local branch_ok, branch = pcall(function()
    local handle = io.popen("git rev-parse --abbrev-ref HEAD 2>/dev/null")
    if handle then
      local result = handle:read("*a"):gsub("\n", "")
      handle:close()
      return result
    end
    return ""
  end)
  State.git_branch = (branch_ok and branch ~= "") and branch or ""
  return State.git_branch
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
  for _, client in pairs(clients) do
    table.insert(names, client.name)
  end
  return table.concat(names, ",")
end

local function get_total_lines()
  return string.format("%dL", vim.fn.line("$"))
end

local function get_buffer_number()
  return string.format("B%d", vim.fn.bufnr())
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

local function mode_component()
  local mode = get_mode()
  return string.format("%%#StatuslineMode# %s %%*%%#StatuslineNormal# ", mode)
end

local function branch_component()
  local branch = get_git_info()
  if branch == "" then return "" end
  return string.format("%%#StatuslineBranch# %s %%*", branch)
end

local function filepath_component()
  local path = get_filepath()
  return string.format("%%#StatuslineFilepath# %s %%*", path)
end

local function filetype_component()
  local ft = get_filetype()
  return string.format("%%#StatuslineFiletype# %s %%*", ft)
end

local function encoding_component()
  local enc = get_encoding()
  return string.format("%%#StatuslineEncoding# %s %%*", enc)
end

local function word_count_component()
  local wc = get_word_count()
  if wc == "" then return "" end
  return string.format("%%#StatuslinePosition# %s %%*", wc)
end

local function file_size_component()
  local size = get_file_size()
  if size == "" then return "" end
  return string.format("%%#StatuslinePosition# %s %%*", size)
end

local function total_lines_component()
  return string.format("%%#StatuslinePosition# %s %%*", get_total_lines())
end

local function buffer_number_component()
  return string.format("%%#StatuslinePosition# %s %%*", get_buffer_number())
end

local function lsp_component()
  local lsp = get_lsp_status()
  if lsp == "" then return "" end
  return string.format("%%#StatuslineLSP#  %s %%*", lsp)
end

local function indent_component()
  return string.format("%%#StatuslineIndent# %s %%*", get_indent_info())
end

local function session_component()
  return string.format("%%#StatuslineSession#%s %%*", get_session_info())
end

local function progress_component()
  local prog = get_progress()
  return string.format("%%#StatuslinePosition# %s %%*", prog)
end

local function location_component()
  local loc = get_location()
  return string.format("%%#StatuslinePosition# %s %%*", loc)
end

local function render()
  local statusline = mode_component()
  .. indent_component()
  .. session_component()
  .. filepath_component()
  .. branch_component()
  .. lsp_component()
  .. word_count_component()
  .. filetype_component()
  .. file_size_component()
  .. total_lines_component()
  .. buffer_number_component()
  .. encoding_component()
  .. progress_component()
  .. location_component()
  return statusline .. "%#StatuslineNormal#"
end

local function setup_highlights()
  vim.cmd(string.format([[
    hi StatuslineNormal guibg=%s guifg=%s |
    hi StatuslineMode guibg=%s guifg=%s gui=bold |
    hi StatuslineBranch guibg=%s guifg=%s |
    hi StatuslineFilepath guibg=%s guifg=%s |
    hi StatuslineFiletype guibg=%s guifg=%s |
    hi StatuslineEncoding guibg=%s guifg=%s |
    hi StatuslinePosition guibg=%s guifg=%s |
    hi StatuslineIndent guibg=%s guifg=%s |
    hi StatuslineSession guibg=%s guifg=%s gui=bold |
    hi StatuslineLSP guibg=%s guifg=%s
  ]],
    colors.bg, colors.position_fg,
    colors.mode_bg, colors.mode_fg,
    colors.bg, colors.branch_fg,
    colors.bg, colors.filepath_fg,
    colors.bg, colors.filetype_fg,
    colors.bg, colors.encoding_fg,
    colors.bg, colors.position_fg,
    colors.bg, colors.indent_fg,
    colors.bg, colors.session_fg,
    colors.bg, colors.lsp_fg
  ))
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

vim.api.nvim_create_autocmd({"BufEnter", "BufWritePost", "CursorMoved", "CursorMovedI", "ModeChanged"}, {
  callback = function()
    if vim.v.event.event == "BufEnter" then State.git_last_check = 0 end
    vim.cmd("redrawstatus")
  end,
})

return {}
