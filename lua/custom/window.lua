local Window = {}

function Window.create_float(opts)
    opts = opts or {}
    local width = opts.width or 60
    local height = opts.height or 10
    local title = opts.title or ""
    local enter = opts.enter ~= false
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].buflisted = false
    local win = vim.api.nvim_open_win(buf, enter, {
        relative = "editor",
        width = width,
        height = height,
        col = (vim.o.columns - width) / 2,
        row = (vim.o.lines - height) / 2,
        style = "minimal",
        border = opts.border or "rounded",
        title = title,
        title_pos = opts.title_pos or "center",
    })
    pcall(vim.api.nvim_win_set_option, win, "winblend", 0)
    pcall(vim.api.nvim_set_option_value, "winhighlight", "Normal:Normal,FloatBorder:FloatBorder", { win = win })
    return buf, win
end

function Window.create_input(opts)
    opts = opts or {}
    local title = opts.title or "Input"
    local default_text = opts.default_text or ""
    local callback = opts.callback or function() end
    local parent_win = opts.parent_win
    local buf, win = Window.create_float({ width = opts.width or 60, height = opts.height or 3, title = title, border = "rounded" })
    vim.bo[buf].modifiable = true
    if default_text and default_text ~= "" then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { default_text })
    end
    vim.cmd("startinsert")
    local function close_and_callback()
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local text = lines[1] or ""
        vim.api.nvim_win_close(win, true)
        if parent_win and vim.api.nvim_win_is_valid(parent_win) then
            vim.api.nvim_set_current_win(parent_win)
            vim.cmd("stopinsert")
        end
        callback(text)
    end
    vim.keymap.set({ "n", "i" }, "<CR>", close_and_callback, { buffer = buf, silent = true })
    vim.keymap.set({ "n", "i" }, "<Esc>", function()
        vim.api.nvim_win_close(win, true)
        if parent_win and vim.api.nvim_win_is_valid(parent_win) then
            vim.api.nvim_set_current_win(parent_win)
            vim.cmd("stopinsert")
        end
        callback(nil)
    end, { buffer = buf, silent = true })
    return buf, win
end

function Window.create_select(opts)
    opts = opts or {}
    local title = opts.title or "Select"
    local items = opts.items or {}
    local callback = opts.callback or function() end
    local parent_win = opts.parent_win
    local buf, win = Window.create_float({ width = opts.width or 40, height = #items + 2, title = title, border = "rounded" })
    vim.bo[buf].modifiable = true
    local display_lines = {}
    for i, item in ipairs(items) do
        table.insert(display_lines, string.format("%d. %s", i, item))
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_lines)
    vim.bo[buf].modifiable = false
    local function select_item()
        local line = vim.api.nvim_win_get_cursor(win)[1]
        local selected = items[line]
        vim.api.nvim_win_close(win, true)
        if parent_win and vim.api.nvim_win_is_valid(parent_win) then
            vim.api.nvim_set_current_win(parent_win)
        end
        callback(selected)
    end
    vim.keymap.set("n", "<CR>", select_item, { buffer = buf, silent = true })
    vim.keymap.set("n", "<Esc>", function()
        vim.api.nvim_win_close(win, true)
        if parent_win and vim.api.nvim_win_is_valid(parent_win) then
            vim.api.nvim_set_current_win(parent_win)
        end
        callback(nil)
    end, { buffer = buf, silent = true })
    vim.keymap.set("n", "q", function()
        vim.api.nvim_win_close(win, true)
        if parent_win and vim.api.nvim_win_is_valid(parent_win) then
            vim.api.nvim_set_current_win(parent_win)
        end
        callback(nil)
    end, { buffer = buf, silent = true })
    for i = 1, #items do
        vim.keymap.set("n", tostring(i), function()
            vim.api.nvim_win_close(win, true)
            if parent_win and vim.api.nvim_win_is_valid(parent_win) then
                vim.api.nvim_set_current_win(parent_win)
            end
            callback(items[i])
        end, { buffer = buf, silent = true })
    end
    return buf, win
end

function Window.create_layout(opts)
    opts = opts or {}
    local width_ratio = opts.width_ratio or 0.8
    local height_ratio = opts.height_ratio or 0.7
    local preview_width_ratio = opts.preview_width_ratio or 0.5
    local total_width = math.floor(vim.o.columns * width_ratio)
    local total_height = math.floor(vim.o.lines * height_ratio)
    local row = math.floor((vim.o.lines - total_height) / 2)
    local col = math.floor((vim.o.columns - total_width) / 2)
    if total_width < 40 or total_height < 10 then
        error("Window too small")
    end
    local results_width = math.floor(total_width * (1 - preview_width_ratio)) - 1
    local preview_width = total_width - results_width - 1
    local input_height = opts.input_height or 3
    local results_height = total_height - input_height - 1
    if results_width < 10 or preview_width < 10 or results_height < 5 then
        error("Window dimensions too small")
    end
    local results_buf = vim.api.nvim_create_buf(false, true)
    local preview_buf = vim.api.nvim_create_buf(false, true)
    local input_buf = vim.api.nvim_create_buf(false, true)
    for _, buf in ipairs({ results_buf, preview_buf, input_buf }) do
        pcall(vim.api.nvim_buf_set_option, buf, "buftype", "nofile")
        pcall(vim.api.nvim_buf_set_option, buf, "bufhidden", "wipe")
        pcall(vim.api.nvim_buf_set_option, buf, "swapfile", false)
        pcall(vim.api.nvim_buf_set_option, buf, "buflisted", false)
    end
    local results_win = vim.api.nvim_open_win(results_buf, false, {
        relative = "editor",
        width = results_width,
        height = results_height,
        row = row,
        col = col,
        border = "single",
        style = "minimal",
        title = opts.results_title or " Results ",
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
        title = opts.preview_title or " Preview ",
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
        title = opts.input_title or "",
        title_pos = "center"
    })
    pcall(vim.api.nvim_win_set_option, input_win, "winblend", 0)
    pcall(vim.api.nvim_set_option_value, "winhighlight", "Normal:Normal,FloatBorder:FloatBorder", { win = input_win })
    return { results = { buf = results_buf, win = results_win }, preview = { buf = preview_buf, win = preview_win }, input = { buf = input_buf, win = input_win } }
end

function Window.safe_delete_buffer(buf)
    if buf and vim.api.nvim_buf_is_valid(buf) then
        pcall(vim.api.nvim_buf_set_option, buf, "modified", false)
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
end

function Window.safe_close_window(win)
    if win and vim.api.nvim_win_is_valid(win) then
        pcall(vim.api.nvim_win_close, win, true)
    end
end

return Window
