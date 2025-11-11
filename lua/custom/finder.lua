local api = vim.api
local fn = vim.fn

local Finder = {}

local state = {
  buf = nil,
  win = nil,
  is_open = false
}

local ignored = { "node_modules", ".git", "dist" }

local function createWindow()
  local width = math.floor(vim.o.columns * 0.7)
  local height = math.floor(vim.o.lines * 0.6)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  local buf = api.nvim_create_buf(false, true)
  pcall(api.nvim_buf_set_option, buf, "buftype", "prompt")
  pcall(api.nvim_buf_set_option, buf, "bufhidden", "wipe")
  pcall(api.nvim_buf_set_option, buf, "swapfile", false)
  pcall(api.nvim_buf_set_option, buf, "buflisted", false)
  local ok, win = pcall(api.nvim_open_win, buf, true, { relative = "editor", width = width, height = height, row = row, col = col, border = "single", style = "minimal", title = " Finder ", title_pos = "center" })
  if not ok then
    pcall(api.nvim_buf_delete, buf, { force = true })
    error("Failed to create finder window")
  end
  pcall(api.nvim_win_set_option, win, "winblend", 0)
  pcall(api.nvim_set_option_value, "winhighlight", "Normal:Normal,FloatBorder:FloatBorder", { win = win })
  return buf, win
end

local function isIgnored(path)
  for _, pattern in pairs(ignored) do
    if string.find(path, pattern) then
      return true
    end
  end
  return false
end

local function getFiles()
  if fn.executable("find") == 1 then
    local exclude_args = {}
    for _, pattern in pairs(ignored) do
      table.insert(exclude_args, string.format("-path './%s' -prune -o", pattern))
    end
    local cmd = string.format("find . %s -type f -print 2>/dev/null", table.concat(exclude_args, " "))
    return fn.systemlist(cmd)
  end
  local files = {}
  local stack = { "." }
  while #stack > 0 do
    local path = table.remove(stack)
    local ok, entries = pcall(fn.readdir, path)
    if not ok or not entries then
      goto continue
    end
    for _, name in pairs(entries) do
      if name == "." or name == ".." then
        goto continue_inner
      end
      local full = path .. "/" .. name
      if isIgnored(full) then
        goto continue_inner
      end
      if fn.isdirectory(full) == 1 then
        table.insert(stack, full)
        goto continue_inner
      end
      table.insert(files, full)
      ::continue_inner::
    end
    ::continue::
  end
  return files
end

local function filterFiles(files, query)
  if not query or query == "" then return files end
  local q = query:lower()
  local out = {}
  for _, f in pairs(files) do
    if not isIgnored(f) and string.find(f:lower(), q, 1, true) then table.insert(out, f) end
  end
  return out
end

local function safeBuf(buf)
  if not buf then return end
  if api.nvim_buf_is_valid(buf) then
    pcall(api.nvim_buf_set_option, buf, "modified", false)
    pcall(api.nvim_buf_delete, buf, { force = true })
  end
end

local function safeClose(win, buf)
  if win and api.nvim_win_is_valid(win) then pcall(api.nvim_win_close, win, true) end
  safeBuf(buf)
  state.buf = nil
  state.win = nil
  state.is_open = false
  vim.schedule(function()
    pcall(vim.cmd, "redraw!")
    pcall(vim.cmd, "mode")
  end)
end

function Finder.status()
  return state.is_open and state.win and api.nvim_win_is_valid(state.win) and state.buf and api.nvim_buf_is_valid(state.buf)
end

function Finder.close()
  if Finder.status() then safeClose(state.win, state.buf) end
end

function Finder.toggle()
  if Finder.status() then return Finder.close() end
  Finder.open()
  print("Finder mode: enabled")
end

function Finder.open()
  if Finder.status() then return end
  local ok, files = pcall(getFiles)
  if not ok or not files then
    vim.notify("Failed to list files", vim.log.levels.ERROR)
    return
  end
  local filtered = vim.deepcopy(files)
  local buf, win = createWindow()
  state.buf = buf
  state.win = win
  state.is_open = true
  fn.prompt_setprompt(buf, "> ")
  api.nvim_buf_set_lines(buf, 1, -1, false, filtered)
  local function refresh(input)
    local ok2, out = pcall(filterFiles, files, input)
    if not ok2 then
      api.nvim_buf_set_lines(buf, 1, -1, false, { "Error filtering files" })
      return
    end
    filtered = out
    api.nvim_buf_set_lines(buf, 1, -1, false, filtered)
  end
  fn.prompt_setcallback(buf, refresh)
  local function close()
    safeClose(win, buf)
  end
  api.nvim_create_autocmd("WinClosed", {
    buffer = buf,
    once = true,
    callback = function()
      state.buf = nil
      state.win = nil
      state.is_open = false
    end,
  })
  vim.keymap.set("n", "<CR>", function()
    local line = fn.getline(".")
    close()
    vim.defer_fn(function()
      if not line or line == "" then return end
      pcall(vim.cmd, "edit " .. fn.fnameescape(line))
    end, 8)
  end, { buffer = buf, silent = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, silent = true })
  vim.keymap.set("n", "q", close, { buffer = buf, silent = true })
  if #filtered > 0 then
    api.nvim_win_set_cursor(win, { 2, 0 })
  end
end

return Finder
