local Window = {}

local function setup_buffer(buf)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].buflisted = false
end

local function setup_window(win)
    pcall(vim.api.nvim_win_set_option, win, "winblend", 0)
    pcall(vim.api.nvim_set_option_value, "winhighlight", "Normal:Normal,FloatBorder:FloatBorder", { win = win })
end

local function create_window(buf, config)
    local win = vim.api.nvim_open_win(buf, config.enter or false, {
        relative = "editor",
        width = config.width,
        height = config.height,
        row = config.row,
        col = config.col,
        style = "minimal",
        border = config.border or "rounded",
        title = config.title or "",
        title_pos = config.title_pos or "center",
    })
    setup_window(win)
    return win
end

local function get_centered_pos(width, height)
    return { row = math.floor((vim.o.lines - height) / 2), col = math.floor((vim.o.columns - width) / 2) }
end

function Window.create_float(opts)
    opts = opts or {}
    local width = opts.width or 60
    local height = opts.height or 10
    local buf = vim.api.nvim_create_buf(false, true)
    setup_buffer(buf)
    local pos = get_centered_pos(width, height)
    local win = create_window(buf, {
        width = width,
        height = height,
        row = pos.row,
        col = pos.col,
        border = opts.border,
        title = opts.title or "",
        title_pos = opts.title_pos,
        enter = opts.enter ~= false
    })
    return buf, win
end

local function close_with_callback(win, buf, parent_win, callback, value)
    vim.api.nvim_win_close(win, true)
    if parent_win and vim.api.nvim_win_is_valid(parent_win) then
        vim.api.nvim_set_current_win(parent_win)
        vim.cmd("stopinsert")
    end
    callback(value)
end

function Window.create_input(opts)
    opts = opts or {}
    local callback = opts.callback or function() end
    local parent_win = opts.parent_win
    local buf, win = Window.create_float({
        width = opts.width or 60,
        height = opts.height or 3,
        title = opts.title or "Input",
        border = "rounded"
    })
    vim.bo[buf].modifiable = true
    if opts.default_text and opts.default_text ~= "" then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { opts.default_text })
    end
    vim.cmd("startinsert")
    local function on_submit()
        local text = vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1] or ""
        close_with_callback(win, buf, parent_win, callback, text)
    end
    local function on_cancel()
        close_with_callback(win, buf, parent_win, callback, nil)
    end
    vim.keymap.set({ "n", "i" }, "<CR>", on_submit, { buffer = buf, silent = true })
    vim.keymap.set({ "n", "i" }, "<Esc>", on_cancel, { buffer = buf, silent = true })
    return buf, win
end

function Window.create_select(opts)
    opts = opts or {}
    local items = opts.items or {}
    local callback = opts.callback or function() end
    local parent_win = opts.parent_win
    local buf, win = Window.create_float({
        width = opts.width or 40,
        height = #items + 2,
        title = opts.title or "Select",
        border = "rounded"
    })
    vim.bo[buf].modifiable = true
    local display_lines = {}
    for i, item in ipairs(items) do
        table.insert(display_lines, string.format("%d. %s", i, item))
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_lines)
    vim.bo[buf].modifiable = false
    local function select_item(idx)
        close_with_callback(win, buf, parent_win, callback, items[idx])
    end
    local function cancel()
        close_with_callback(win, buf, parent_win, callback, nil)
    end
    vim.keymap.set("n", "<CR>", function()
        local line = vim.api.nvim_win_get_cursor(win)[1]
        select_item(line)
    end, { buffer = buf, silent = true })
    vim.keymap.set("n", "<Esc>", cancel, { buffer = buf, silent = true })
    vim.keymap.set("n", "q", cancel, { buffer = buf, silent = true })
    for i = 1, #items do
        vim.keymap.set("n", tostring(i), function()
            select_item(i)
        end, { buffer = buf, silent = true })
    end
    return buf, win
end

local function create_panel(config)
    local buf = vim.api.nvim_create_buf(false, true)
    setup_buffer(buf)
    local win = create_window(buf, config)
    return { buf = buf, win = win }
end

function Window.create_split_two(opts)
    opts = opts or {}
    local width_ratio = opts.width_ratio or 0.8
    local height_ratio = opts.height_ratio or 0.7
    local preview_width_ratio = opts.preview_width_ratio or 0.5
    local total_width = math.floor(vim.o.columns * width_ratio)
    local total_height = math.floor(vim.o.lines * height_ratio)
    local pos = get_centered_pos(total_width, total_height)
    if total_width < 40 or total_height < 10 then
        error("Window too small.")
    end
    local results_width = math.floor(total_width * (1 - preview_width_ratio)) - 1
    local preview_width = total_width - results_width - 1
    local input_height = opts.input_height or 3
    local results_height = total_height - input_height - 1
    if results_width < 10 or preview_width < 10 or results_height < 5 then
        error("Window dimensions too small.")
    end
    return {
        results = create_panel({
            width = results_width,
            height = results_height,
            row = pos.row,
            col = pos.col,
            border = "single",
            title = opts.results_title or " Results ",
        }),
        preview = create_panel({
            width = preview_width,
            height = results_height,
            row = pos.row,
            col = pos.col + results_width + 1,
            border = "single",
            title = opts.preview_title or " Preview ",
        }),
        input = create_panel({
            width = total_width,
            height = input_height,
            row = pos.row + results_height + 1,
            col = pos.col,
            border = "single",
            title = opts.input_title or "",
        })
    }
end

function Window.create_split_three(opts)
    opts = opts or {}
    local width_ratio = opts.width_ratio or 0.9
    local height_ratio = opts.height_ratio or 0.8
    local left_width_ratio = opts.left_width_ratio or 0.30
    local middle_width_ratio = opts.middle_width_ratio or 0.35
    local total_width = math.floor(vim.o.columns * width_ratio)
    local total_height = math.floor(vim.o.lines * height_ratio)
    local pos = get_centered_pos(total_width, total_height)
    if total_width < 60 or total_height < 20 then
        error("Window too small for three-panel layout.")
    end
    local left_width = math.floor(total_width * left_width_ratio)
    local middle_width = math.floor(total_width * middle_width_ratio)
    local right_width = total_width - left_width - middle_width - 2
    if left_width < 10 or middle_width < 10 or right_width < 10 then
        error("Panel dimensions too small.")
    end
    return {
        left = create_panel({
            width = left_width,
            height = total_height,
            row = pos.row,
            col = pos.col,
            border = "single",
            title = opts.left_title or " Left ",
        }),
        middle = create_panel({
            width = middle_width,
            height = total_height,
            row = pos.row,
            col = pos.col + left_width + 1,
            border = "single",
            title = opts.middle_title or " Middle ",
        }),
        right = create_panel({
            width = right_width,
            height = total_height,
            row = pos.row,
            col = pos.col + left_width + middle_width + 2,
            border = "single",
            title = opts.right_title or " Right ",
        })
    }
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
