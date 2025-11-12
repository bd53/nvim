local Finder = {}

local config = {
  ignored_patterns = { ".git", "target", "node_modules", "dist" },
  window = { width_ratio = 0.8, height_ratio = 0.7 },
  preview = { width_ratio = 0.5 },
}

local state = {
  buf = nil,
  win = nil,
  preview_buf = nil,
  preview_win = nil,
  input_buf = nil,
  input_win = nil,
  is_open = false,
  files = {},
  filtered_files = {},
  query = "",
}

local function is_ignored(path)
  for _, pattern in pairs(config.ignored_patterns) do
    if path:find(pattern) then return true end
  end
  return false
end

local function is_valid_state()
  return state.is_open and state.win and vim.api.nvim_win_is_valid(state.win)
end

local function safe_delete_buffer(buf)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_set_option, buf, "modified", false)
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
end

local function reset_state()
  state.buf = nil
  state.win = nil
  state.preview_buf = nil
  state.preview_win = nil
  state.input_buf = nil
  state.input_win = nil
  state.is_open = false
  state.files = {}
  state.filtered_files = {}
  state.query = ""
end

local function close_finder()
  if state.win and vim.api.nvim_win_is_valid(state.win) then pcall(vim.api.nvim_win_close, state.win, true) end
  if state.preview_win and vim.api.nvim_win_is_valid(state.preview_win) then pcall(vim.api.nvim_win_close, state.preview_win, true) end
  if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then pcall(vim.api.nvim_win_close, state.input_win, true) end
  safe_delete_buffer(state.buf)
  safe_delete_buffer(state.preview_buf)
  safe_delete_buffer(state.input_buf)
  reset_state()
  vim.schedule(function()
    pcall(vim.cmd, "redraw!")
    pcall(vim.cmd, "mode")
  end)
end

local function get_all_files()
  if vim.fn.executable("find") == 1 then
    local exclude_args = {}
    for _, pattern in pairs(config.ignored_patterns) do
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

local function update_preview()
  if not state.preview_buf or not vim.api.nvim_buf_is_valid(state.preview_buf) then return end
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end
  local cursor = vim.api.nvim_win_get_cursor(state.win)
  local line_num = cursor[1]
  if line_num < 1 or line_num > #state.filtered_files then
    vim.api.nvim_buf_set_lines(state.preview_buf, 0, -1, false, { "-- Preview --" })
    return
  end
  local file = state.filtered_files[line_num]
  if not file or file == "" then
    vim.api.nvim_buf_set_lines(state.preview_buf, 0, -1, false, { "-- Preview --" })
    return
  end
  local ok, lines = pcall(vim.fn.readfile, file, "", 200)
  if ok and lines then
    vim.api.nvim_buf_set_lines(state.preview_buf, 0, -1, false, lines)
    local ft = vim.filetype.match({ filename = file })
    if ft then
      pcall(vim.api.nvim_buf_set_option, state.preview_buf, "filetype", ft)
    end
  else
    vim.api.nvim_buf_set_lines(state.preview_buf, 0, -1, false, { "-- Cannot preview file --" })
  end
end

local function create_results_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  pcall(vim.api.nvim_buf_set_option, buf, "buftype", "nofile")
  pcall(vim.api.nvim_buf_set_option, buf, "bufhidden", "wipe")
  pcall(vim.api.nvim_buf_set_option, buf, "swapfile", false)
  pcall(vim.api.nvim_buf_set_option, buf, "buflisted", false)
  return buf
end

local function create_preview_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  pcall(vim.api.nvim_buf_set_option, buf, "buftype", "nofile")
  pcall(vim.api.nvim_buf_set_option, buf, "bufhidden", "wipe")
  pcall(vim.api.nvim_buf_set_option, buf, "swapfile", false)
  pcall(vim.api.nvim_buf_set_option, buf, "buflisted", false)
  return buf
end

local function create_input_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  pcall(vim.api.nvim_buf_set_option, buf, "buftype", "nofile")
  pcall(vim.api.nvim_buf_set_option, buf, "bufhidden", "wipe")
  pcall(vim.api.nvim_buf_set_option, buf, "swapfile", false)
  pcall(vim.api.nvim_buf_set_option, buf, "buflisted", false)
  return buf
end

local function create_windows(results_buf, preview_buf, input_buf)
  local total_width = math.floor(vim.o.columns * config.window.width_ratio)
  local total_height = math.floor(vim.o.lines * config.window.height_ratio)
  local row = math.floor((vim.o.lines - total_height) / 2)
  local col = math.floor((vim.o.columns - total_width) / 2)
  if total_width < 40 or total_height < 10 then
    safe_delete_buffer(results_buf)
    safe_delete_buffer(preview_buf)
    safe_delete_buffer(input_buf)
  end
  local results_width = math.floor(total_width * (1 - config.preview.width_ratio)) - 1
  local preview_width = total_width - results_width - 1
  local input_height = 3
  local results_height = total_height - input_height - 1
  if results_width < 10 or preview_width < 10 or results_height < 5 then
    safe_delete_buffer(results_buf)
    safe_delete_buffer(preview_buf)
    safe_delete_buffer(input_buf)
  end
  local results_win = vim.api.nvim_open_win(results_buf, false, {
    relative = "editor",
    width = results_width,
    height = results_height,
    row = row,
    col = col,
    border = "single",
    style = "minimal",
    title = " Results ",
    title_pos = "center"
  })
  pcall(vim.api.nvim_win_set_option, results_win, "winblend", 0)
  pcall(vim.api.nvim_set_option_value, "winhighlight", "Normal:Normal,FloatBorder:FloatBorder", { win = results_win })
  local preview_win = vim.api.nvim_open_win(preview_buf, false, {
    relative = "editor",
    width = preview_width,
    height = results_height,
    row = row,
    col = col + results_width + 1,
    border = "single",
    style = "minimal",
    title = " Preview ",
    title_pos = "center"
  })
  pcall(vim.api.nvim_win_set_option, preview_win, "winblend", 0)
  pcall(vim.api.nvim_set_option_value, "winhighlight", "Normal:Normal,FloatBorder:FloatBorder", { win = preview_win })
  local input_win = vim.api.nvim_open_win(input_buf, false, {
    relative = "editor",
    width = total_width,
    height = input_height,
    row = row + results_height + 1,
    col = col,
    border = "single",
    style = "minimal",
    title = "",
    title_pos = "center"
  })
  pcall(vim.api.nvim_win_set_option, input_win, "winblend", 0)
  pcall(vim.api.nvim_set_option_value, "winhighlight", "Normal:Normal,FloatBorder:FloatBorder", { win = input_win })
  return results_win, preview_win, input_win
end

local function refresh_results()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end
  state.filtered_files = filter_files(state.files, state.query)
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, state.filtered_files)
  local count_text = string.format("%d / %d", #state.filtered_files, #state.files)
  if state.input_buf and vim.api.nvim_buf_is_valid(state.input_buf) then
    vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, { "> " .. state.query, count_text })
  end
  if state.win and vim.api.nvim_win_is_valid(state.win) and #state.filtered_files > 0 then
    pcall(vim.api.nvim_win_set_cursor, state.win, { 1, 0 })
  end
  update_preview()
end

local function setup_keymaps(results_buf, input_buf)
  vim.keymap.set("n", "<CR>", function()
    if not state.win or not vim.api.nvim_win_is_valid(state.win) then return end
    local cursor = vim.api.nvim_win_get_cursor(state.win)
    local line_num = cursor[1]
    if line_num >= 1 and line_num <= #state.filtered_files then
      local file = state.filtered_files[line_num]
      close_finder()
      vim.defer_fn(function()
        if file and file ~= "" then
          pcall(vim.cmd, "edit " .. vim.fn.fnameescape(file))
        end
      end, 8)
    end
  end, { buffer = results_buf, silent = true })
  vim.keymap.set("n", "<Esc>", close_finder, { buffer = results_buf, silent = true })
  vim.keymap.set("n", "q", close_finder, { buffer = results_buf, silent = true })
  vim.keymap.set("n", "j", function()
    local cursor = vim.api.nvim_win_get_cursor(state.win)
    if cursor[1] < #state.filtered_files then
      vim.api.nvim_win_set_cursor(state.win, { cursor[1] + 1, 0 })
      update_preview()
    end
  end, { buffer = results_buf, silent = true })
  vim.keymap.set("n", "k", function()
    local cursor = vim.api.nvim_win_get_cursor(state.win)
    if cursor[1] > 1 then
      vim.api.nvim_win_set_cursor(state.win, { cursor[1] - 1, 0 })
      update_preview()
    end
  end, { buffer = results_buf, silent = true })
  vim.keymap.set("n", "s", function()
    if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
      vim.api.nvim_set_current_win(state.input_win)
      vim.cmd("startinsert")
      vim.api.nvim_win_set_cursor(state.input_win, { 1, #state.query + 2 })
    end
  end, { buffer = results_buf, silent = true })
  vim.keymap.set("i", "<CR>", function()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
      vim.api.nvim_set_current_win(state.win)
      local cursor = vim.api.nvim_win_get_cursor(state.win)
      local line_num = cursor[1]
      if line_num >= 1 and line_num <= #state.filtered_files then
        local file = state.filtered_files[line_num]
        close_finder()
        vim.defer_fn(function()
          if file and file ~= "" then
            pcall(vim.cmd, "edit " .. vim.fn.fnameescape(file))
          end
        end, 8)
      end
    end
  end, { buffer = input_buf, silent = true })
  vim.keymap.set("i", "<Esc>", function()
    vim.cmd("stopinsert")
    if state.win and vim.api.nvim_win_is_valid(state.win) then
      vim.api.nvim_set_current_win(state.win)
    end
  end, { buffer = input_buf, silent = true })
  vim.keymap.set("n", "<Esc>", close_finder, { buffer = input_buf, silent = true })
  vim.keymap.set("n", "q", close_finder, { buffer = input_buf, silent = true })
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = input_buf,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(input_buf, 0, 1, false)
      if lines and lines[1] then
        state.query = lines[1]:gsub("^> ", "")
        refresh_results()
      end
    end
  })
end

local function setup_autocmds(results_buf)
  vim.api.nvim_create_autocmd("WinClosed", {
    buffer = results_buf,
    once = true,
    callback = function()
      close_finder()
    end
  })
  vim.api.nvim_create_autocmd("CursorMoved", { buffer = results_buf, callback = update_preview })
end

local function open_finder()
  if is_valid_state() then return end
  local ok, files = pcall(get_all_files)
  if not ok or not files then return end
  state.files = files
  state.filtered_files = vim.deepcopy(files)
  state.query = ""
  local results_buf = create_results_buffer()
  local preview_buf = create_preview_buffer()
  local input_buf = create_input_buffer()
  local ok_win, results_win, preview_win, input_win = pcall(create_windows, results_buf, preview_buf, input_buf)
  if not ok_win then
    safe_delete_buffer(results_buf)
    safe_delete_buffer(preview_buf)
    safe_delete_buffer(input_buf)
    print("Failed to create finder windows: " .. tostring(results_win))
    return
  end
  state.buf = results_buf
  state.win = results_win
  state.preview_buf = preview_buf
  state.preview_win = preview_win
  state.input_buf = input_buf
  state.input_win = input_win
  state.is_open = true
  vim.api.nvim_buf_set_lines(results_buf, 0, -1, false, state.filtered_files)
  vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, { "> ", string.format("%d / %d", #files, #files) })
  setup_keymaps(results_buf, input_buf)
  setup_autocmds(results_buf)
  vim.api.nvim_set_current_win(results_win)
  if #state.filtered_files > 0 then
    pcall(vim.api.nvim_win_set_cursor, results_win, { 1, 0 })
    update_preview()
  end
end

function Finder.toggle()
  if is_valid_state() then close_finder() return end
  open_finder()
end

return Finder
