local M = {}

-- https://github.com/ellisonleao/gruvbox.nvim/blob/main/lua/gruvbox.lua#L74
---@class GruvboxPalette
M.palette = {
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

M.current_mode = "dark"

local function highlight(p)
  local set = vim.api.nvim_set_hl
  if M.current_mode == "dark" then
    vim.cmd("set background=dark")
    set(0, "Normal", { fg = p.light1, bg = p.dark0 })
    set(0, "Comment", { fg = p.dark4, italic = true })
    set(0, "Keyword", { fg = p.bright_purple })
    set(0, "Function", { fg = p.bright_yellow })
    set(0, "String", { fg = p.bright_green })
    set(0, "Identifier", { fg = p.bright_blue })
    set(0, "Type", { fg = p.bright_aqua })
    set(0, "Number", { fg = p.bright_orange })
  else
    vim.cmd("set background=light")
    set(0, "Normal", { fg = p.dark1, bg = p.light0 })
    set(0, "Comment", { fg = p.light4, italic = true })
    set(0, "Keyword", { fg = p.neutral_purple })
    set(0, "Function", { fg = p.neutral_yellow })
    set(0, "String", { fg = p.neutral_green })
    set(0, "Identifier", { fg = p.neutral_blue })
    set(0, "Type", { fg = p.neutral_aqua })
    set(0, "Number", { fg = p.neutral_orange })
  end
end

function M.toggle()
  M.current_mode = (M.current_mode == "dark") and "light" or "dark"
  M.apply()
  print(("Gruvbox mode: %s"):format(M.current_mode))
end

function M.apply()
  highlight(M.palette)
end

return M
