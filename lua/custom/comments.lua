local Comments = {}

local Config = {
  keywords = { "@todo", "@fix", "@ignore" },
  comment_string = "//",
}

local function setup_highlights()
  vim.cmd("highlight CommentKeyword guifg=#5fad48 gui=bold")
  for _, keyword in pairs(Config.keywords) do
    vim.fn.matchadd("CommentKeyword", keyword)
  end
end

function Comments.toggle()
  local line = vim.api.nvim_get_current_line()
  local pattern = "^%s*" .. vim.pesc(Config.comment_string)
  if line:match(pattern) then
    line = line:gsub(pattern .. "%s?", "")
    vim.api.nvim_set_current_line(line)
    return
  end
  line = Config.comment_string .. " " .. line
  vim.api.nvim_set_current_line(line)
end

setup_highlights()

return Comments
