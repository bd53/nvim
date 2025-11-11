local Finder = {}

local Config = {
  ignored_patterns = { "node_modules", ".git", "dist" },
  window = { width_ratio = 0.7, height_ratio = 0.6 },
}

local State = { buf = nil, win = nil, is_open = false }

local function is_ignored(path)
  for _, pattern in pairs(Config.ignored_patterns) do
    if path:find(pattern) then return true end
  end
  return false
end

local function is_valid_state()
  return State.is_open and State.win and vim.api.nvim_win_is_valid(State.win) and State.buf and vim.api.nvim_buf_is_valid(State.buf)
end

local function safe_delete_buffer(buf)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_set_option, buf, "modified", false)
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
end

local function reset_state()
  State.buf = nil
  State.win = nil
  State.is_open = false
end

local function close_finder()
  if State.win and vim.api.nvim_win_is_valid(State.win) then pcall(vim.api.nvim_win_close, State.win, true) end
  safe_delete_buffer(State.buf)
  reset_state()
  vim.schedule(function()
    pcall(vim.cmd, "redraw!")
    pcall(vim.cmd, "mode")
  end)
end

local function get_all_files()
  if vim.fn.executable("find") == 1 then
    local exclude_args = {}
    for _, pattern in pairs(Config.ignored_patterns) do
      table.insert(exclude_args, string.format("-path './%s' -prune -o", pattern))
    end
    local cmd = string.format("find . %s -type f -print 2>/dev/null", table.concat(exclude_args, " "))
    return vim.fn.systemlist(cmd)
  end
  local files = {}
  local stack = { "." }
  while #stack > 0 do
    local path = table.remove(stack)
    local ok, entries = pcall(vim.fn.readdir, path)
    if not ok or not entries then
      goto continue_path
    end
    for _, name in pairs(entries) do
      if name == "." or name == ".." then
        goto continue_entry
      end
      local full_path = path .. "/" .. name
      if is_ignored(full_path) then
        goto continue_entry
      end
      if vim.fn.isdirectory(full_path) == 1 then
        table.insert(stack, full_path)
        goto continue_entry
      end
      -- if not a dir
      table.insert(files, full_path)
      ::continue_entry::
    end
    ::continue_path::
  end
  return files
end

local function filter_files(files, query)
  if not query or query == "" then return files end
  local normalized_query = query:lower()
  local filtered = {}
  for _, file in pairs(files) do
    if not is_ignored(file) and file:lower():find(normalized_query, 1, true) then
      table.insert(filtered, file)
    end
  end
  return filtered
end

local function create_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  pcall(vim.api.nvim_buf_set_option, buf, "buftype", "prompt")
  pcall(vim.api.nvim_buf_set_option, buf, "bufhidden", "wipe")
  pcall(vim.api.nvim_buf_set_option, buf, "swapfile", false)
  pcall(vim.api.nvim_buf_set_option, buf, "buflisted", false)
  return buf
end

local function create_window(buf)
  local width = math.floor(vim.o.columns * Config.window.width_ratio)
  local height = math.floor(vim.o.lines * Config.window.height_ratio)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  local ok, win = pcall(vim.api.nvim_open_win, buf, true, { relative = "editor", width = width, height = height, row = row, col = col, border = "single", style = "minimal", title = " Finder ", title_pos = "center" })
  if not ok then
    safe_delete_buffer(buf)
    error("Failed to create finder window")
  end
  pcall(vim.api.nvim_win_set_option, win, "winblend", 0)
  pcall(vim.api.nvim_set_option_value, "winhighlight", "Normal:Normal,FloatBorder:FloatBorder", { win = win })
  return win
end

local function setup_keymaps(buf)
  vim.keymap.set("n", "<CR>", function()
    local line = vim.fn.getline(".")
    close_finder()
    vim.defer_fn(function()
      if line and line ~= "" then
        pcall(vim.cmd, "edit " .. vim.fn.fnameescape(line))
      end
    end, 8)
  end, { buffer = buf, silent = true })
  vim.keymap.set("n", "<Esc>", close_finder, { buffer = buf, silent = true })
  vim.keymap.set("n", "q", close_finder, { buffer = buf, silent = true })
end

local function setup_autocmds(buf)
  vim.api.nvim_create_autocmd("WinClosed", { buffer = buf, once = true, callback = reset_state })
end

local function setup_prompt(buf, files)
  vim.fn.prompt_setprompt(buf, "> ")
  local function refresh_display(input)
    local ok, filtered = pcall(filter_files, files, input)
    if not ok then vim.api.nvim_buf_set_lines(buf, 1, -1, false, { "Error filtering files" }) return end
    vim.api.nvim_buf_set_lines(buf, 1, -1, false, filtered)
  end
  vim.fn.prompt_setcallback(buf, refresh_display)
end

local function open_finder()
  if is_valid_state() then return end
  local ok, files = pcall(get_all_files)
  if not ok or not files then return end
  local buf = create_buffer()
  local win = create_window(buf)
  State.buf = buf
  State.win = win
  State.is_open = true
  setup_prompt(buf, files)
  setup_keymaps(buf)
  setup_autocmds(buf)
  local filtered = vim.deepcopy(files)
  vim.api.nvim_buf_set_lines(buf, 1, -1, false, filtered)
  if #filtered > 0 then
    vim.api.nvim_win_set_cursor(win, { 2, 0 })
  end
end

function Finder.toggle()
  if is_valid_state() then close_finder() return end
  open_finder()
  print("Finder mode: enabled")
end

return Finder
