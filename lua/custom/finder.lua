local Window = require("custom.window")
local Finder = {}

local config = {
    ignored_patterns = { ".git", "target", "node_modules", "dist", "bin", "output" },
    window = { width_ratio = 0.8, height_ratio = 0.7 },
    preview = { width_ratio = 0.5 },
}

local state = {
    layout = nil,
    is_open = false,
    files = {},
    all_results = {},
    query = "",
}

--#region Utilities

local function is_ignored(path)
    for _, pattern in ipairs(config.ignored_patterns) do
        if path:find(pattern) then return true end
    end
    return false
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

local function search_and_filter(query)
    if not query or query == "" then
        local results = {}
        for _, file in ipairs(state.files) do
            table.insert(results, { type = "file", file = file, display = file })
        end
        return results
    end
    local results = {}
    local normalized_query = query:lower()
    for _, file in ipairs(state.files) do
        if file:lower():find(normalized_query, 1, true) then
            table.insert(results, { type = "file", file = file, display = "[F] " .. file })
        end
    end
    local escaped_query = query:gsub("'", "'\\''")
    local grep_output = {}
    if vim.fn.executable("rg") == 1 then
        local exclude_args = {}
        for _, pattern in ipairs(config.ignored_patterns) do
            table.insert(exclude_args, string.format("--glob '!%s'", pattern))
        end
        local cmd = string.format("rg --line-number --no-heading --color=never %s '%s' 2>/dev/null", table.concat(exclude_args, " "), escaped_query)
        grep_output = vim.fn.systemlist(cmd)
    elseif vim.fn.executable("grep") == 1 then
        local exclude_args = {}
        for _, pattern in ipairs(config.ignored_patterns) do
            table.insert(exclude_args, string.format("--exclude-dir='%s'", pattern))
        end
        local cmd = string.format("grep -rn %s '%s' . 2>/dev/null", table.concat(exclude_args, " "), escaped_query)
        grep_output = vim.fn.systemlist(cmd)
    end
    for _, line in ipairs(grep_output) do
        local file, line_num, content = line:match("^([^:]+):(%d+):(.*)$")
        if file and line_num and content then
            table.insert(results, { type = "grep", file = file, line_num = tonumber(line_num), content = content, display = "[G] " .. line })
        end
    end
    return results
end

--#endregion Utilities

local function finder_helper()
    if not state.layout or not state.layout.results.win then return end
    if not vim.api.nvim_win_is_valid(state.layout.results.win) then return end
    if not state.layout.preview.buf or not vim.api.nvim_buf_is_valid(state.layout.preview.buf) then return end
    local cursor = vim.api.nvim_win_get_cursor(state.layout.results.win)
    local line_num = cursor[1]
    if line_num < 1 or line_num > #state.all_results then vim.api.nvim_buf_set_lines(state.layout.preview.buf, 0, -1, false, { "Preview." }) return end
    local result = state.all_results[line_num]
    if not result then vim.api.nvim_buf_set_lines(state.layout.preview.buf, 0, -1, false, { "Preview." }) return end
    local ok, file_lines = pcall(vim.fn.readfile, result.file)
    if not ok or not file_lines then vim.api.nvim_buf_set_lines(state.layout.preview.buf, 0, -1, false, { "Cannot preview file." }) return end
    if result.type == "grep" then
        local context_before = 5
        local context_after = 5
        local start_line = math.max(1, result.line_num - context_before)
        local end_line = math.min(#file_lines, result.line_num + context_after)
        local preview_lines = {}
        for i = start_line, end_line do
            local prefix = (i == result.line_num) and ">>> " or "    "
            table.insert(preview_lines, string.format("%s%4d: %s", prefix, i, file_lines[i]))
        end
        vim.api.nvim_buf_set_lines(state.layout.preview.buf, 0, -1, false, preview_lines)
        local ft = vim.filetype.match({ filename = result.file })
        if ft then pcall(vim.api.nvim_buf_set_option, state.layout.preview.buf, "filetype", ft) end
        if state.layout.preview.win and vim.api.nvim_win_is_valid(state.layout.preview.win) then
            local match_line_in_preview = result.line_num - start_line + 1
            pcall(vim.api.nvim_win_set_cursor, state.layout.preview.win, { match_line_in_preview, 0 })
        end
    else
        local preview_lines = {}
        for i = 1, math.min(#file_lines, 200) do
            table.insert(preview_lines, file_lines[i])
        end
        vim.api.nvim_buf_set_lines(state.layout.preview.buf, 0, -1, false, preview_lines)
        local ft = vim.filetype.match({ filename = result.file })
        if ft then pcall(vim.api.nvim_buf_set_option, state.layout.preview.buf, "filetype", ft) end
    end
end

function Finder.toggle()
    if state.is_open and state.layout and state.layout.results and state.layout.results.win and vim.api.nvim_win_is_valid(state.layout.results.win) then if state.layout and state.layout.close then state.layout.close() end return end
    local ok, files = pcall(get_all_files)
    if not ok or not files then vim.notify("Failed to get file list", vim.log.levels.ERROR) return end
    state.files = files
    state.query = ""
    state.all_results = search_and_filter("")
    local ok_layout, layout = pcall(Window.create_split_two, {
        width_ratio = config.window.width_ratio,
        height_ratio = config.window.height_ratio,
        preview_width_ratio = config.preview.width_ratio,
        results_title = " Search ",
        preview_title = " Preview ",
        input_title = "",
        input_height = 3,
        on_close = function()
            state.layout = nil
            state.is_open = false
            state.files = {}
            state.all_results = {}
            state.query = ""
        end
    })
    if not ok_layout then vim.notify(("Failed to create finder windows: %s"):format(tostring(layout)), vim.log.levels.ERROR) return end
    state.layout = layout
    state.is_open = true
    local results_buf = state.layout.results.buf
    local input_buf = state.layout.input.buf
    vim.keymap.set({ "n", "i" }, "<CR>", function()
        if not state.layout or not state.layout.results.win then return end
        if not vim.api.nvim_win_is_valid(state.layout.results.win) then return end
        local cursor = vim.api.nvim_win_get_cursor(state.layout.results.win)
        local line_num = cursor[1]
        if line_num < 1 or line_num > #state.all_results then return end
        local result = state.all_results[line_num]
        if not result or not result.file or result.file == "" then return end
        local file = result.file
        local target_line = result.line_num
        if state.layout.close then state.layout.close() end
        vim.defer_fn(function()
            pcall(vim.cmd, "edit " .. vim.fn.fnameescape(file))
            if target_line then
                pcall(vim.api.nvim_win_set_cursor, 0, { target_line, 0 })
                vim.cmd("normal! zz")
            end
        end, 10)
    end, { buffer = results_buf, silent = true })
    vim.keymap.set("n", "s", function()
        if not state.layout or not state.layout.input.win then return end
        if not vim.api.nvim_win_is_valid(state.layout.input.win) then return end
        vim.api.nvim_set_current_win(state.layout.input.win)
        vim.cmd("startinsert")
        vim.api.nvim_win_set_cursor(state.layout.input.win, { 1, #state.query + 2 })
    end, { buffer = results_buf, silent = true })
    vim.keymap.set("i", "<Esc>", function()
        vim.cmd("stopinsert")
        if not state.layout or not state.layout.results.win then return end
        if not vim.api.nvim_win_is_valid(state.layout.results.win) then return end
        vim.api.nvim_set_current_win(state.layout.results.win)
    end, { buffer = input_buf, silent = true })
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        buffer = input_buf,
        callback = function()
            if not state.layout or not state.layout.input.buf then return end
            local lines = vim.api.nvim_buf_get_lines(state.layout.input.buf, 0, 1, false)
            if lines and lines[1] then
                state.query = lines[1]:gsub("^> ", "")
                if not state.layout or not state.layout.results.buf then return end
                if not vim.api.nvim_buf_is_valid(state.layout.results.buf) then return end
                state.all_results = search_and_filter(state.query)
                local display_lines = {}
                for _, result in ipairs(state.all_results) do
                    table.insert(display_lines, result.display)
                end
                vim.api.nvim_buf_set_lines(state.layout.results.buf, 0, -1, false, display_lines)
                if state.layout.input.buf and vim.api.nvim_buf_is_valid(state.layout.input.buf) then
                    local count_text = string.format("%d results", #state.all_results)
                    vim.api.nvim_buf_set_lines(state.layout.input.buf, 0, -1, false, { "> " .. state.query, count_text })
                end
                if state.layout.results.win and vim.api.nvim_win_is_valid(state.layout.results.win) and #state.all_results > 0 then
                    pcall(vim.api.nvim_win_set_cursor, state.layout.results.win, { 1, 0 })
                end
                finder_helper()
            end
        end
    })
    vim.api.nvim_create_autocmd("CursorMoved", {
        buffer = state.layout.results.buf,
        callback = finder_helper
    })
    local display_lines = {}
    for _, result in ipairs(state.all_results) do
        table.insert(display_lines, result.display)
    end
    vim.api.nvim_buf_set_lines(state.layout.results.buf, 0, -1, false, display_lines)
    vim.api.nvim_buf_set_lines(state.layout.input.buf, 0, -1, false, { "> ", string.format("%d results", #state.all_results) })
    vim.api.nvim_set_current_win(state.layout.results.win)
    if #state.all_results > 0 then
        pcall(vim.api.nvim_win_set_cursor, state.layout.results.win, { 1, 0 })
        finder_helper()
    end
end

return Finder
