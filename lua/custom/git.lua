local Window = require("custom.window")
local Git = {}

local blame_state = {
    namespace = vim.api.nvim_create_namespace("git_blame"),
    timer = nil,
    last_line = nil,
    enabled = false,
}

local history_state = {
    layout = nil,
    is_open = false,
    items = {},
}

local changes_state = {
    layout = nil,
    is_open = false,
    items = {},
}

local status_labels = {
    ["M "] = "Modified",
    [" M"] = "Modified (unstaged)",
    ["MM"] = "Modified (staged + unstaged)",
    ["A "] = "Added",
    ["D "] = "Deleted",
    ["R "] = "Renamed",
    ["C "] = "Copied",
    ["U "] = "Updated",
    ["??"] = "Untracked",
}

--#region Utilities

local function run_git_cmd(cmd)
    local ok, output = pcall(vim.fn.systemlist, cmd)
    if ok and output and #output > 0 then return output end
    return nil
end

local function format_date(ts, commit)
    if ts and ts ~= 0 then return os.date("%m/%d/%y", ts) end
    local out = run_git_cmd("git show -s --format=%ct " .. commit)
    local ct = tonumber(out and out[1])
    if ct and ct ~= 0 then return os.date("%m/%d/%y", ct) end
    return "unknown date"
end

local function truncate(text, max_len)
    if #text > max_len then return text:sub(1, max_len - 3) .. "..." end
    return text
end

local function setup_navigation_keymaps(buf, main_win, items, update_callback, enter_callback)
    vim.keymap.set("n", "j", function()
        local cursor = vim.api.nvim_win_get_cursor(main_win)
        if cursor[1] < #items then
            vim.api.nvim_win_set_cursor(main_win, { cursor[1] + 1, 0 })
            update_callback()
        end
    end, { buffer = buf, silent = true })
    vim.keymap.set("n", "k", function()
        local cursor = vim.api.nvim_win_get_cursor(main_win)
        if cursor[1] > 1 then
            vim.api.nvim_win_set_cursor(main_win, { cursor[1] - 1, 0 })
            update_callback()
        end
    end, { buffer = buf, silent = true })
    if enter_callback then
        vim.keymap.set("n", "<CR>", enter_callback, { buffer = buf, silent = true })
    end
end

--#endregion Utilities

--#region Git Blame

local function blame_helper()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    if row == blame_state.last_line then return end
    blame_state.last_line = row
    local file = vim.fn.expand("%:p")
    if file == "" then return end
    local output = run_git_cmd(string.format("git --no-pager blame -L %d,%d --porcelain '%s'", row, row, file))
    if not output then return end
    local commit = output[1]:match("^(%w+)")
    if commit == "0000000000000000000000000000000000000000" then
        local blame = { commit = "", author = os.getenv("USER") or "You", time = os.date("%I:%M %p"), summary = "Not Committed Yet" }
        local author = truncate(blame.author, 20)
        local text = string.format("%s (%s) %s - %s", blame.commit, blame.time, author, blame.summary)
        vim.api.nvim_buf_clear_namespace(0, blame_state.namespace, 0, -1)
        vim.api.nvim_buf_set_extmark(0, blame_state.namespace, row - 1, 0, {
            virt_text = { { text, "Comment" } },
            virt_text_pos = "eol"
        })
        return
    end
    local author, timestamp, summary
    for _, l in ipairs(output) do
        if l:find("^author ") then author = l:sub(8) end
        if l:find("^author-time ") then timestamp = tonumber(l:sub(13)) end
        if l:find("^summary ") then summary = l:sub(9) end
    end
    local blame = { commit = commit:sub(1, 7), author = author, time = format_date(timestamp, commit), summary = summary }
    vim.api.nvim_buf_clear_namespace(0, blame_state.namespace, 0, -1)
    vim.api.nvim_buf_set_extmark(0, blame_state.namespace, row - 1, 0, {
        virt_text = { { string.format("%s (%s) %s - %s", blame.commit or "?", blame.time or "?", truncate(blame.author or "?", 20), blame.summary or "?"), "Comment" } },
        virt_text_pos = "eol"
    })
end

function Git.blame()
    blame_state.enabled = not blame_state.enabled
    if not blame_state.enabled then
        blame_state.timer = nil
        vim.api.nvim_buf_clear_namespace(0, blame_state.namespace, 0, -1)
        vim.api.nvim_clear_autocmds({ group = "GitBlame" })
        blame_state.last_line = nil
        vim.notify("Git blame: disabled", vim.log.levels.WARN)
        return
    end
    vim.cmd("highlight link GitBlameVirtText Comment")
    local group = vim.api.nvim_create_augroup("GitBlame", { clear = true })
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        group = group,
        callback = function()
            blame_state.timer = vim.defer_fn(function()
                pcall(blame_helper)
            end, 100)
        end,
    })
    vim.api.nvim_create_autocmd({ "BufLeave", "InsertEnter" }, {
        group = group,
        callback = function()
            vim.api.nvim_buf_clear_namespace(0, blame_state.namespace, 0, -1)
        end,
    })
    vim.api.nvim_create_autocmd("BufEnter", {
        group = group,
        callback = function()
            blame_state.last_line = nil
            vim.schedule(function()
                blame_state.timer = vim.defer_fn(function()
                    pcall(blame_helper)
                end, 100)
            end)
        end
    })
    vim.schedule(function()
        blame_state.timer = vim.defer_fn(function()
            pcall(blame_helper)
        end, 100)
    end)
    vim.notify("Git blame: enabled", vim.log.levels.WARN)
end

--#endregion Git Blame

--#region Git Diff

local function changes_helper()
    if not changes_state.layout or not changes_state.layout.preview.buf then return end
    if not vim.api.nvim_buf_is_valid(changes_state.layout.preview.buf) then return end
    local main_win = changes_state.layout.results.win
    if not main_win or not vim.api.nvim_win_is_valid(main_win) then return end
    local cursor = vim.api.nvim_win_get_cursor(main_win)
    local line_num = cursor[1]
    if line_num < 1 or line_num > #changes_state.items then vim.api.nvim_buf_set_lines(changes_state.layout.preview.buf, 0, -1, false, {}) return end
    local item = changes_state.items[line_num]
    if not item or not item.file then vim.api.nvim_buf_set_lines(changes_state.layout.preview.buf, 0, -1, false, {}) return end
    local staged_diff = run_git_cmd(string.format("git diff --cached -- '%s'", item.file))
    local unstaged_diff = run_git_cmd(string.format("git diff -- '%s'", item.file))
    local lines = {}
    if staged_diff and staged_diff[1] ~= "" then
        table.insert(lines, "=== STAGED CHANGES ===")
        table.insert(lines, "")
        vim.list_extend(lines, staged_diff)
    end
    if unstaged_diff and unstaged_diff[1] ~= "" then
        if #lines > 0 then
            table.insert(lines, "")
            table.insert(lines, "")
        end
        table.insert(lines, "=== UNSTAGED CHANGES ===")
        table.insert(lines, "")
        vim.list_extend(lines, unstaged_diff)
    end
    if #lines == 0 then
        local content = run_git_cmd(string.format("git show HEAD:'%s' 2>/dev/null || cat '%s'", item.file, item.file))
        if content then
            table.insert(lines, "=== NEW FILE ===")
            table.insert(lines, "")
            vim.list_extend(lines, content)
        end
    end
    vim.api.nvim_buf_set_lines(changes_state.layout.preview.buf, 0, -1, false, #lines > 0 and lines or {})
    pcall(vim.api.nvim_buf_set_option, changes_state.layout.preview.buf, "filetype", "diff")
end

function Git.changes()
    if changes_state.is_open and changes_state.layout and changes_state.layout.results and changes_state.layout.results.win and vim.api.nvim_win_is_valid(changes_state.layout.results.win) then if changes_state.layout and changes_state.layout.close then changes_state.layout.close() end return end
    local output = run_git_cmd("git status --porcelain")
    if not output then output = {} end
    local files = {}
    for _, line in ipairs(output) do
        if line ~= "" then
            local status = line:sub(1, 2)
            local file = line:sub(4)
            local label = status_labels[status] or "Unknown"
            local display = string.format("[%s] %s", label, file)
            table.insert(files, { status = status, file = file, display = display, label = label })
        end
    end
    changes_state.items = files
    local ok_layout, layout = pcall(Window.create_split_two, {
        width_ratio = 0.8,
        height_ratio = 0.7,
        preview_width_ratio = 0.6,
        results_title = string.format(" Edited (%d) ", #files),
        preview_title = " Preview ",
        input_title = "",
        input_height = 1,
        on_close = function()
            changes_state.layout = nil
            changes_state.is_open = false
            changes_state.items = {}
        end
    })
    if not ok_layout then vim.notify("Failed to create changes windows: " .. tostring(layout), vim.log.levels.ERROR) return end
    changes_state.layout = layout
    changes_state.is_open = true
    if layout.input and layout.input.win then
        pcall(vim.api.nvim_win_close, layout.input.win, true)
    end
    local display_lines = #files > 0 and vim.tbl_map(function(f) return f.display end, files) or {}
    vim.api.nvim_buf_set_lines(changes_state.layout.results.buf, 0, -1, false, display_lines)
    setup_navigation_keymaps(changes_state.layout.results.buf, changes_state.layout.results.win, changes_state.items, changes_helper, function()
        local main_win = changes_state.layout.results.win
        if not main_win or not vim.api.nvim_win_is_valid(main_win) then return end
        local cursor = vim.api.nvim_win_get_cursor(main_win)
        local line_num = cursor[1]
        if line_num < 1 or line_num > #changes_state.items then return end
        local item = changes_state.items[line_num]
        if item and item.file and item.file ~= "" then
            if changes_state.layout and changes_state.layout.close then
                changes_state.layout.close()
            end
            vim.defer_fn(function()
                pcall(vim.cmd, "edit " .. vim.fn.fnameescape(item.file))
            end, 10)
        end
    end)
    vim.api.nvim_create_autocmd("CursorMoved", {
        buffer = changes_state.layout.results.buf,
        callback = changes_helper,
    })
    vim.api.nvim_set_current_win(changes_state.layout.results.win)
    if #files > 0 then
        pcall(vim.api.nvim_win_set_cursor, changes_state.layout.results.win, { 1, 0 })
        changes_helper()
    end
end

--#endregion Git Diff

--#region Git History

local function history_helper()
    if not history_state.layout then return end
    if not history_state.layout.middle.buf or not vim.api.nvim_buf_is_valid(history_state.layout.middle.buf) then return end
    if not history_state.layout.right.buf or not vim.api.nvim_buf_is_valid(history_state.layout.right.buf) then return end
    local main_win = history_state.layout.left.win
    if not main_win or not vim.api.nvim_win_is_valid(main_win) then return end
    local cursor = vim.api.nvim_win_get_cursor(main_win)
    local line_num = cursor[1]
    if line_num < 1 or line_num > #history_state.items then
        vim.api.nvim_buf_set_lines(history_state.layout.middle.buf, 0, -1, false, {})
        vim.api.nvim_buf_set_lines(history_state.layout.right.buf, 0, -1, false, {})
        return
    end
    local item = history_state.items[line_num]
    if not item or not item.hash then
        vim.api.nvim_buf_set_lines(history_state.layout.middle.buf, 0, -1, false, {})
        vim.api.nvim_buf_set_lines(history_state.layout.right.buf, 0, -1, false, {})
        return
    end
    vim.api.nvim_buf_set_lines(history_state.layout.middle.buf, 0, -1, false, run_git_cmd(string.format("git show --stat --pretty=format:'Commit: %%H%%nAuthor: %%an <%%ae>%%nDate: %%ar (%%ad)%%n%%nMessage: %%s%%n%%b%%n' %s", item.hash)) or {})
    pcall(vim.api.nvim_buf_set_option, history_state.layout.middle.buf, "filetype", "git")
    local diff_output = run_git_cmd(string.format("git show --pretty=format:'' %s", item.hash))
    local diff = {}
    if diff_output then
        if #diff_output > 0 and diff_output[1] == "" then
            table.remove(diff_output, 1)
        end
        diff = diff_output
    end
    vim.api.nvim_buf_set_lines(history_state.layout.right.buf, 0, -1, false, diff)
    pcall(vim.api.nvim_buf_set_option, history_state.layout.right.buf, "filetype", "diff")
end

function Git.history()
    if history_state.is_open and history_state.layout and history_state.layout.left and history_state.layout.left.win and vim.api.nvim_win_is_valid(history_state.layout.left.win) then if history_state.layout and history_state.layout.close then history_state.layout.close() end return end
    local output = run_git_cmd("git log --pretty=format:'%h|%an|%ar|%s' -50")
    if not output then output = {} end
    local commits = {}
    for _, line in ipairs(output) do
        if line ~= "" then
            local parts = vim.split(line, "|", { plain = true })
            if #parts >= 4 then
                local hash, author, time, message = parts[1], parts[2], parts[3], parts[4]
                author = truncate(author, 20)
                local display = string.format("%s  %s  %s  %s", hash, time, author, message)
                table.insert(commits, { hash = hash, author = author, time = time, message = message, display = display })
            end
        end
    end
    history_state.items = commits
    local ok_layout, layout = pcall(Window.create_split_three, {
        width_ratio = 0.95,
        height_ratio = 0.80,
        left_width_ratio = 0.30,
        middle_width_ratio = 0.35,
        left_title = string.format(" Commits (%d) ", #commits),
        middle_title = " Details ",
        right_title = " Changes ",
        on_close = function()
            history_state.layout = nil
            history_state.is_open = false
            history_state.items = {}
        end
    })
    if not ok_layout then vim.notify("Failed to create history windows: " .. tostring(layout), vim.log.levels.ERROR) return end
    history_state.layout = layout
    history_state.is_open = true
    vim.api.nvim_buf_set_lines(history_state.layout.left.buf, 0, -1, false, #commits > 0 and vim.tbl_map(function(c) return c.display end, commits) or {})
    setup_navigation_keymaps(history_state.layout.left.buf, history_state.layout.left.win, history_state.items, history_helper, function()
        local main_win = history_state.layout.left.win
        if not main_win or not vim.api.nvim_win_is_valid(main_win) then return end
        local cursor = vim.api.nvim_win_get_cursor(main_win)
        local line_num = cursor[1]
        if line_num < 1 or line_num > #history_state.items then return end
        local item = history_state.items[line_num]
        if item and item.hash then
            vim.fn.setreg("+", item.hash)
            vim.notify("Copied commit hash: " .. item.hash, vim.log.levels.INFO)
        end
    end)
    vim.api.nvim_create_autocmd("CursorMoved", {
        buffer = history_state.layout.left.buf,
        callback = history_helper,
    })
    vim.api.nvim_set_current_win(history_state.layout.left.win)
    if #commits > 0 then
        pcall(vim.api.nvim_win_set_cursor, history_state.layout.left.win, { 1, 0 })
        history_helper()
    end
end

--#endregion Git History

return Git
