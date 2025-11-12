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
    filtered_files = {},
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
        if not ok or not entries then
            goto continue_path
        end
        for _, name in ipairs(entries) do
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
    for _, file in ipairs(files) do
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
    local ok_layout, layout = pcall(Window.create_layout, {
        width_ratio = config.window.width_ratio,
        height_ratio = config.window.height_ratio,
        preview_width_ratio = config.preview.width_ratio,
        results_title = " Results ",
        preview_title = " Preview ",
        input_title = "",
        input_height = 3,
    })
    if not ok_layout then
        print("Failed to create finder windows: " .. tostring(layout))
        return
    end
    state.buf = layout.results.buf
    state.win = layout.results.win
    state.preview_buf = layout.preview.buf
    state.preview_win = layout.preview.win
    state.input_buf = layout.input.buf
    state.input_win = layout.input.win
    state.is_open = true
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, state.filtered_files)
    vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, { "> ", string.format("%d / %d", #files, #files) })
    setup_keymaps(state.buf, state.input_buf)
    setup_autocmds(state.buf)
    vim.api.nvim_set_current_win(state.win)
    if #state.filtered_files > 0 then
        pcall(vim.api.nvim_win_set_cursor, state.win, { 1, 0 })
        update_preview()
    end
end

function Finder.toggle()
    if is_valid_state() then
        close_finder()
        return
    end
    open_finder()
end

return Finder
