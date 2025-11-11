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
  for _, kw in pairs(Config.keywords) do
    local group_name = "CommentKeyword" .. kw.word:gsub("@", "")
    vim.cmd(string.format("highlight %s guifg=%s gui=bold", group_name, kw.color))
  end
end

local function highlight_keywords()
  local ft = vim.bo.filetype
  local comment_str = Config.comment_strings[ft] or "//"
  for _, kw in pairs(Config.keywords) do
    local hl_group = "CommentKeyword" .. kw.word:gsub("@", "")
    local pattern = vim.pesc(comment_str) .. ".*" .. vim.pesc(kw.word)
    vim.fn.matchadd(hl_group, pattern)
  end
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
highlight_keywords()

return Comments
