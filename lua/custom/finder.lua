local Window = require("custom.window")
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
    all_results = {},
    query = "",
}

local function is_ignored(path)
    for _, pattern in ipairs(config.ignored_patterns) do
        if path:find(pattern) then return true end
    end
    return false
end

local function is_valid_state()
    return state.is_open and state.win and vim.api.nvim_win_is_valid(state.win)
end

local function reset_state()
    for k in pairs(state) do
        if k == "is_open" then state[k] = false
        elseif k == "files" or k == "all_results" then state[k] = {}
        elseif k == "query" then state[k] = ""
        else state[k] = nil end
    end
end

local function close_finder()
    Window.safe_close_window(state.win)
    Window.safe_close_window(state.preview_win)
    Window.safe_close_window(state.input_win)
    Window.safe_delete_buffer(state.buf)
    Window.safe_delete_buffer(state.preview_buf)
    Window.safe_delete_buffer(state.input_buf)
    reset_state()
    vim.schedule(function()
        pcall(vim.cmd, "redraw!")
        pcall(vim.cmd, "mode")
    end)
end

local function get_all_files()
    if vim.fn.executable("find") == 1 then
        local exclude_args = {}
        for _, pattern in ipairs(config.ignored_patterns) do
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
        if ok and entries then
            for _, name in ipairs(entries) do
                if name ~= "." and name ~= ".." then
                    local full_path = path .. "/" .. name
                    if not is_ignored(full_path) then
                        if vim.fn.isdirectory(full_path) == 1 then
                            table.insert(stack, full_path)
                        else
                            table.insert(files, full_path)
                        end
                    end
                end
            end
        end
    end
    return files
end

local function search_content(query)
    if not query or query == "" then return {} end
    local results = {}
    local exclude_args = {}
    for _, pattern in ipairs(config.ignored_patterns) do
        table.insert(exclude_args, string.format("--glob '!%s'", pattern))
    end
    if vim.fn.executable("rg") == 1 then
        local output = vim.fn.systemlist(string.format("rg --line-number --no-heading --color=never %s '%s' 2>/dev/null", table.concat(exclude_args, " "), query:gsub("'", "'\\''")))
        for _, line in ipairs(output) do
            table.insert(results, line)
        end
    elseif vim.fn.executable("grep") == 1 then
        local exclude_str = ""
        for _, pattern in ipairs(config.ignored_patterns) do
            exclude_str = exclude_str .. string.format("--exclude-dir='%s' ", pattern)
        end
        local output = vim.fn.systemlist(string.format("grep -rn %s '%s' . 2>/dev/null", exclude_str, query:gsub("'", "'\\''")))
        for _, line in ipairs(output) do
            table.insert(results, line)
        end
    end
    return results
end

local function filter_files(files, query)
    if not query or query == "" then return {} end
    local normalized_query = query:lower()
    local filtered = {}
    for _, file in ipairs(files) do
        if file:lower():find(normalized_query, 1, true) then
            table.insert(filtered, file)
        end
    end
    return filtered
end

local function parse_grep_result(line)
    local file, line_num, content = line:match("^([^:]+):(%d+):(.*)$")
    if file and line_num and content then return { type = "grep", file = file, line_num = tonumber(line_num), content = content, display = line } end
    return nil
end

local function build_unified_results(query)
    if not query or query == "" then
        local results = {}
        for _, file in ipairs(state.files) do
            table.insert(results, { type = "file", file = file, display = file })
        end
        return results
    end
    local results = {}
    local matching_files = filter_files(state.files, query)
    for _, file in ipairs(matching_files) do
        table.insert(results, {  type = "file", file = file, display = "[!] " .. file })
    end
    local grep_results = search_content(query)
    for _, line in ipairs(grep_results) do
        local parsed = parse_grep_result(line)
        if parsed then
            table.insert(results, { type = "grep", file = parsed.file, line_num = parsed.line_num, content = parsed.content, display = "[!] " .. line })
        end
    end
    return results
end

local function update_preview()
    if not state.preview_buf or not vim.api.nvim_buf_is_valid(state.preview_buf) then return end
    if not state.win or not vim.api.nvim_win_is_valid(state.win) then return end
    local cursor = vim.api.nvim_win_get_cursor(state.win)
    local line_num = cursor[1]
    if line_num < 1 or line_num > #state.all_results then
        vim.api.nvim_buf_set_lines(state.preview_buf, 0, -1, false, { "Preview." })
        return
    end
    local result = state.all_results[line_num]
    if not result then
        vim.api.nvim_buf_set_lines(state.preview_buf, 0, -1, false, { "Preview." })
        return
    end
    local ok, lines = pcall(vim.fn.readfile, result.file)
    if not ok or not lines then
        vim.api.nvim_buf_set_lines(state.preview_buf, 0, -1, false, { "Cannot preview file." })
        return
    end
    if result.type == "grep" then
        local context_before = 5
        local context_after = 5
        local start_line = math.max(1, result.line_num - context_before)
        local end_line = math.min(#lines, result.line_num + context_after)
        local preview_lines = {}
        for i = start_line, end_line do
            local prefix = (i == result.line_num) and ">>> " or "    "
            table.insert(preview_lines, string.format("%s%4d: %s", prefix, i, lines[i]))
        end
        vim.api.nvim_buf_set_lines(state.preview_buf, 0, -1, false, preview_lines)
        local ft = vim.filetype.match({ filename = result.file })
        if ft then
            pcall(vim.api.nvim_buf_set_option, state.preview_buf, "filetype", ft)
        end
        if state.preview_win and vim.api.nvim_win_is_valid(state.preview_win) then
            local match_line_in_preview = result.line_num - start_line + 1
            pcall(vim.api.nvim_win_set_cursor, state.preview_win, { match_line_in_preview, 0 })
        end
    else
        local preview_lines = {}
        for i = 1, math.min(#lines, 200) do
            table.insert(preview_lines, lines[i])
        end
        vim.api.nvim_buf_set_lines(state.preview_buf, 0, -1, false, preview_lines)
        local ft = vim.filetype.match({ filename = result.file })
        if ft then
            pcall(vim.api.nvim_buf_set_option, state.preview_buf, "filetype", ft)
        end
    end
end

local function refresh_results()
    if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end
    state.all_results = build_unified_results(state.query)
    local display_lines = {}
    for _, result in ipairs(state.all_results) do
        table.insert(display_lines, result.display)
    end
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, display_lines)
    local count_text = string.format("%d results", #state.all_results)
    if state.input_buf and vim.api.nvim_buf_is_valid(state.input_buf) then
        vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, { "> " .. state.query, count_text })
    end
    if state.win and vim.api.nvim_win_is_valid(state.win) and #state.all_results > 0 then
        pcall(vim.api.nvim_win_set_cursor, state.win, { 1, 0 })
    end
    update_preview()
end

local function open_selected_file()
    if not state.win or not vim.api.nvim_win_is_valid(state.win) then return end
    local cursor = vim.api.nvim_win_get_cursor(state.win)
    local line_num = cursor[1]
    if line_num < 1 or line_num > #state.all_results then return end
    local result = state.all_results[line_num]
    if not result or not result.file or result.file == "" then return end
    local file = result.file
    local target_line = result.line_num
    close_finder()
    vim.defer_fn(function()
        pcall(vim.cmd, "edit " .. vim.fn.fnameescape(file))
        if target_line then
            pcall(vim.api.nvim_win_set_cursor, 0, { target_line, 0 })
            vim.cmd("normal! zz")
        end
    end, 8)
end

local function switch_to_input()
    if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
        vim.api.nvim_set_current_win(state.input_win)
        vim.cmd("startinsert")
        vim.api.nvim_win_set_cursor(state.input_win, { 1, #state.query + 2 })
    end
end

local function switch_to_results()
    vim.cmd("stopinsert")
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_set_current_win(state.win)
    end
end

local function setup_keymaps(results_buf, input_buf)
    vim.keymap.set({"n", "i"}, "<CR>", open_selected_file, { buffer = results_buf, silent = true })
    vim.keymap.set("n", "<Esc>", close_finder, { buffer = results_buf, silent = true })
    vim.keymap.set("n", "q", close_finder, { buffer = results_buf, silent = true })
    vim.keymap.set("n", "s", switch_to_input, { buffer = results_buf, silent = true })
    vim.keymap.set("i", "<Esc>", switch_to_results, { buffer = input_buf, silent = true })
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
        callback = close_finder
    })
    vim.api.nvim_create_autocmd("CursorMoved", {
        buffer = results_buf,
        callback = update_preview
    })
end

local function open_finder()
    if is_valid_state() then return end
    local ok, files = pcall(get_all_files)
    if not ok or not files then return end
    state.files = files
    state.query = ""
    state.all_results = build_unified_results("")
    local ok_layout, layout = pcall(Window.create_split_two, {
        width_ratio = config.window.width_ratio,
        height_ratio = config.window.height_ratio,
        preview_width_ratio = config.preview.width_ratio,
        results_title = " Search ",
        preview_title = " Preview ",
        input_title = "",
        input_height = 3,
    })
    if not ok_layout then vim.notify(("Failed to create finder windows: %s"):format(tostring(layout)), vim.log.levels.ERROR) return end
    state.buf = layout.results.buf
    state.win = layout.results.win
    state.preview_buf = layout.preview.buf
    state.preview_win = layout.preview.win
    state.input_buf = layout.input.buf
    state.input_win = layout.input.win
    state.is_open = true
    local display_lines = {}
    for _, result in ipairs(state.all_results) do
        table.insert(display_lines, result.display)
    end
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, display_lines)
    vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, { "> ", string.format("%d results", #state.all_results) })
    setup_keymaps(state.buf, state.input_buf)
    setup_autocmds(state.buf)
    vim.api.nvim_set_current_win(state.win)
    if #state.all_results > 0 then
        pcall(vim.api.nvim_win_set_cursor, state.win, { 1, 0 })
        update_preview()
    end
end

function Finder.toggle()
    if is_valid_state() then close_finder() return end
    open_finder()
end

return Finder
