local Window = require("custom.window")
local Git = {}

local blame_config = {
    namespace = vim.api.nvim_create_namespace("git_blame"),
    update_delay = 500,
}

local blame_state = { timer = nil, last_line = nil, enabled = false }

local function get_blame(line)
    local file = vim.fn.expand("%:p")
    if file == "" then return nil end
    local cmd = string.format("git --no-pager blame -L %d,%d --porcelain '%s'", line, line, file)
    local ok, output = pcall(vim.fn.systemlist, cmd)
    if not ok or not output or #output == 0 then return nil end
    local commit = output[1]:match("^(%w+)")
    if commit == "0000000000000000000000000000000000000000" then return nil end
    local author, timestamp, summary
    for _, l in ipairs(output) do
        if l:sub(1, 7) == "author " then
            author = l:sub(8)
        end
        if l:sub(1, 12) == "author-time " then
            timestamp = tonumber(l:sub(13))
        end
        if l:sub(1, 8) == "summary " then
            summary = l:sub(9)
        end
    end
    local relative_time = ""
    if timestamp then
        local now = os.time()
        local diff = now - timestamp
        local days = math.floor(diff / 86400)
        local hours = math.floor(diff / 3600)
        local minutes = math.floor(diff / 60)
        if days > 365 then
            relative_time = string.format("%dy ago", math.floor(days / 365))
            return { commit = commit:sub(1, 7), author = author, time = relative_time, summary = summary }
        end
        if days > 30 then
            relative_time = string.format("%dmo ago", math.floor(days / 30))
            return { commit = commit:sub(1, 7), author = author, time = relative_time, summary = summary }
        end
        if days > 0 then
            relative_time = string.format("%dd ago", days)
            return { commit = commit:sub(1, 7), author = author, time = relative_time, summary = summary }
        end
        if hours > 0 then
            relative_time = string.format("%dh ago", hours)
            return { commit = commit:sub(1, 7), author = author, time = relative_time, summary = summary }
        end
        if minutes > 0 then
            relative_time = string.format("%dm ago", minutes)
            return { commit = commit:sub(1, 7), author = author, time = relative_time, summary = summary }
        end
        relative_time = "just now"
    end
    return { commit = commit:sub(1, 7), author = author, time = relative_time, summary = summary }
end

local function clear_blame()
    vim.api.nvim_buf_clear_namespace(0, blame_config.namespace, 0, -1)
end

local function show_blame(line, blame)
    clear_blame()
    if not blame then return end
    local author = blame.author or "?"
    if #author > 20 then
        author = author:sub(1, 17) .. "..."
    end
    local text = string.format("%s (%s) %s - %s", blame.commit or "?", blame.time or "?", author, blame.summary or "?")
    vim.api.nvim_buf_set_extmark(0, blame_config.namespace, line - 1, 0, { virt_text = { { text, "Comment" } }, virt_text_pos = "eol" })
end

local function update_blame()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    if row == blame_state.last_line then return end
    blame_state.last_line = row
    local blame = get_blame(row)
    show_blame(row, blame)
end

local function schedule_update()
    blame_state.timer = vim.defer_fn(function()
        local ok = pcall(update_blame)
        if not ok then clear_blame() end
    end, blame_config.update_delay)
end

local function setup_autocmds()
    vim.cmd("highlight link GitBlameVirtText Comment")
    local group = vim.api.nvim_create_augroup("GitBlame", { clear = true })
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, { group = group, callback = schedule_update })
    vim.api.nvim_create_autocmd({ "BufLeave", "InsertEnter" }, { group = group, callback = clear_blame })
    vim.api.nvim_create_autocmd("BufEnter", {
        group = group,
        callback = function()
            blame_state.last_line = nil
            schedule_update()
        end,
    })
    vim.schedule(function()
        blame_state.last_line = nil
        schedule_update()
    end)
end

function Git.toggle()
    blame_state.enabled = not blame_state.enabled
    if blame_state.enabled then
        setup_autocmds()
        print("Git blame: enabled")
        return
    end
    if blame_state.timer then
        blame_state.timer = nil
    end
    clear_blame()
    vim.api.nvim_clear_autocmds({ group = "GitBlame" })
    blame_state.last_line = nil
    print("Git blame: disabled")
end

local commit_types = { "feat", "fix", "docs", "style", "refactor", "perf", "test", "chore" }

local commit_state = {
    type = "",
    scope = "",
    message = "",
    description = "",
}

local function update_display(buf, win)
    vim.bo[buf].modifiable = true
    local desc_display = ""
    if commit_state.description ~= "" then
        local desc_first_line = commit_state.description:gsub("\n.*", "")
        if #desc_first_line > 51 then
            desc_display = desc_first_line:sub(1, 48) .. "..."
        else
            desc_display = desc_first_line
        end
    end
    local lines = {
        "╭─────────────────────────────────────────────────────────────────╮",
        string.format("│ Type: %-58s │", commit_state.type),
        string.format("│ Scope: %-57s │", commit_state.scope),
        string.format("│ Message: %-55s │", commit_state.message),
        string.format("│ Description: %-51s │", desc_display),
        "╰─────────────────────────────────────────────────────────────────╯",
        "  [1] Select Type    [2] Edit Scope    [3] Edit Message",
        "  [4] Edit Description",
    }
    local commit_scope = commit_state.scope ~= "" and ("(" .. commit_state.scope .. ")") or ""
    local preview = string.format("%s%s: %s", commit_state.type, commit_scope, commit_state.message)
    if commit_state.description ~= "" then
        preview = preview .. "\n\n" .. commit_state.description
    end
    if commit_state.type ~= "" or commit_state.message ~= "" then
        table.insert(lines, "")
        local preview_lines = vim.split(preview, "\n", { plain = true })
        for i, line in ipairs(preview_lines) do
            if i == 1 then
                table.insert(lines, "  Preview: " .. line)
            else
                table.insert(lines, "           " .. line)
            end
        end
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
end

local function do_push()
    vim.notify("Pushing to remote...", vim.log.levels.INFO)
    vim.fn.jobstart({ "git", "push" }, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data)
            if data and data[1] ~= "" then
                local output = table.concat(data, "\n")
                vim.notify(output, vim.log.levels.INFO)
            end
        end,
        on_stderr = function(_, data)
            if data and data[1] ~= "" then
                local output = table.concat(data, "\n")
                vim.notify(output, vim.log.levels.WARN)
            end
        end,
        on_exit = function(_, code)
            if code == 0 then
                vim.notify("Push successful.", vim.log.levels.INFO)
            else
                vim.notify("Push failed - check git output.", vim.log.levels.ERROR)
            end
        end,
    })
end

local function do_commit(win, should_push)
    if commit_state.type == "" then
        vim.notify("Please select a commit type.", vim.log.levels.WARN)
        return
    end
    if commit_state.message == "" then
        vim.notify("Please enter a commit message.", vim.log.levels.WARN)
        return
    end
    local commit_scope = commit_state.scope ~= "" and ("(" .. commit_state.scope .. ")") or ""
    local commit_text = string.format("%s%s: %s", commit_state.type, commit_scope, commit_state.message)
    if commit_state.description ~= "" then
        commit_text = commit_text .. "\n\n" .. commit_state.description
    end
    vim.api.nvim_win_close(win, true)
    vim.notify("Staging and committing: " .. commit_text:gsub("\n.*", "..."), vim.log.levels.INFO)
    vim.fn.jobstart({ "git", "add", "-A" }, {
        on_exit = function(_, stage_code)
            if stage_code == 0 then
                vim.fn.jobstart({ "git", "commit", "-m", commit_text }, {
                    stdout_buffered = true,
                    stderr_buffered = true,
                    on_stdout = function(_, data)
                        if data and data[1] ~= "" then
                            local output = table.concat(data, "\n")
                            vim.notify(output, vim.log.levels.INFO)
                        end
                    end,
                    on_stderr = function(_, data)
                        if data and data[1] ~= "" then
                            local output = table.concat(data, "\n")
                            vim.notify(output, vim.log.levels.ERROR)
                        end
                    end,
                    on_exit = function(_, code)
                        if code == 0 then
                            vim.notify("Commit successful.", vim.log.levels.INFO)
                            commit_state.type = ""
                            commit_state.scope = ""
                            commit_state.message = ""
                            commit_state.description = ""
                            if should_push then
                                do_push()
                            end
                        else
                            vim.notify("Commit failed.", vim.log.levels.ERROR)
                        end
                    end,
                })
            else
                vim.notify("Failed to stage changes.", vim.log.levels.ERROR)
            end
        end,
    })
end

local function setup_keymaps(buf, win)
    vim.keymap.set("n", "1", function()
        Window.create_select({
            title = " Type ",
            items = commit_types,
            callback = function(choice)
                if choice then
                    commit_state.type = choice
                    update_display(buf, win)
                end
            end,
            parent_win = win,
        })
    end, { buffer = buf, silent = true })
    vim.keymap.set("n", "2", function()
        Window.create_input({
            title = " Scope (optional) ",
            default_text = commit_state.scope,
            callback = function(input)
                if input ~= nil then
                    commit_state.scope = input
                    update_display(buf, win)
                end
            end,
            parent_win = win,
        })
    end, { buffer = buf, silent = true })
    vim.keymap.set("n", "3", function()
        Window.create_input({
            title = " Message ",
            default_text = commit_state.message,
            callback = function(input)
                if input and input ~= "" then
                    commit_state.message = input
                    update_display(buf, win)
                end
            end,
            parent_win = win,
        })
    end, { buffer = buf, silent = true })
    vim.keymap.set("n", "4", function()
        Window.create_input({
            title = " Description (optional) ",
            default_text = commit_state.description,
            callback = function(input)
                if input ~= nil then
                    commit_state.description = input
                    update_display(buf, win)
                end
            end,
            parent_win = win,
        })
    end, { buffer = buf, silent = true })
    vim.keymap.set("n", "<Esc>", function()
        vim.api.nvim_win_close(win, true)
        vim.notify("Commit cancelled.", vim.log.levels.WARN)
    end, { buffer = buf, silent = true })
    vim.keymap.set("n", "q", function()
        vim.api.nvim_win_close(win, true)
        vim.notify("Commit cancelled.", vim.log.levels.WARN)
    end, { buffer = buf, silent = true })
    vim.keymap.set("n", "<C-c>", function()
        vim.api.nvim_win_close(win, true)
        vim.notify("Commit cancelled.", vim.log.levels.WARN)
    end, { buffer = buf, silent = true })
    vim.keymap.set("n", "<CR>", function()
        do_commit(win, false)
    end, { buffer = buf, silent = true })
end

function Git.commit()
    commit_state.type = ""
    commit_state.scope = ""
    commit_state.message = ""
    commit_state.description = ""
    local buf, win = Window.create_float({ title = " Commit ", width = 70, height = 16, border = "rounded" })
    vim.bo[buf].modifiable = false
    update_display(buf, win)
    setup_keymaps(buf, win)
end

function Git.push()
    do_push()
end

local changes_state = {
    buf = nil,
    win = nil,
    preview_buf = nil,
    preview_win = nil,
    is_open = false,
    files = {},
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

local function is_changes_valid_state()
    return changes_state.is_open and changes_state.win and vim.api.nvim_win_is_valid(changes_state.win)
end

local function reset_changes_state()
    changes_state.buf = nil
    changes_state.win = nil
    changes_state.preview_buf = nil
    changes_state.preview_win = nil
    changes_state.is_open = false
    changes_state.files = {}
end

local function close_changes()
    Window.safe_close_window(changes_state.win)
    Window.safe_close_window(changes_state.preview_win)
    Window.safe_delete_buffer(changes_state.buf)
    Window.safe_delete_buffer(changes_state.preview_buf)
    reset_changes_state()
    vim.schedule(function()
        pcall(vim.cmd, "redraw!")
        pcall(vim.cmd, "mode")
    end)
end

local function get_changed_files()
    local cmd = "git status --porcelain"
    local ok, output = pcall(vim.fn.systemlist, cmd)
    if not ok or not output then return {} end
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
    return files
end

local function get_file_diff(file)
    local staged_cmd = string.format("git diff --cached -- '%s'", file)
    local unstaged_cmd = string.format("git diff -- '%s'", file)
    local ok_staged, staged_diff = pcall(vim.fn.systemlist, staged_cmd)
    local ok_unstaged, unstaged_diff = pcall(vim.fn.systemlist, unstaged_cmd)
    local lines = {}
    if ok_staged and staged_diff and #staged_diff > 0 and staged_diff[1] ~= "" then
        table.insert(lines, "=== STAGED CHANGES ===")
        table.insert(lines, "")
        for _, line in ipairs(staged_diff) do
            table.insert(lines, line)
        end
    end
    if ok_unstaged and unstaged_diff and #unstaged_diff > 0 and unstaged_diff[1] ~= "" then
        if #lines > 0 then
            table.insert(lines, "")
            table.insert(lines, "")
        end
        table.insert(lines, "=== UNSTAGED CHANGES ===")
        table.insert(lines, "")
        for _, line in ipairs(unstaged_diff) do
            table.insert(lines, line)
        end
    end
    if #lines == 0 then
        local show_cmd = string.format("git show HEAD:'%s' 2>/dev/null || cat '%s'", file, file)
        local ok_show, content = pcall(vim.fn.systemlist, show_cmd)
        if ok_show and content then
            table.insert(lines, "=== NEW FILE ===")
            table.insert(lines, "")
            for _, line in ipairs(content) do
                table.insert(lines, line)
            end
        end
    end
    if #lines == 0 then return { "No changes to display." } end
    return lines
end

local function update_diff_preview()
    if not changes_state.preview_buf or not vim.api.nvim_buf_is_valid(changes_state.preview_buf) then return end
    if not changes_state.buf or not vim.api.nvim_buf_is_valid(changes_state.buf) then return end
    local cursor = vim.api.nvim_win_get_cursor(changes_state.win)
    local line_num = cursor[1]
    if line_num < 1 or line_num > #changes_state.files then
        vim.api.nvim_buf_set_lines(changes_state.preview_buf, 0, -1, false, { "No changes to display." })
        return
    end
    local file_info = changes_state.files[line_num]
    if not file_info or not file_info.file then
        vim.api.nvim_buf_set_lines(changes_state.preview_buf, 0, -1, false, { "No changes to display." })
        return
    end
    local diff_lines = get_file_diff(file_info.file)
    vim.api.nvim_buf_set_lines(changes_state.preview_buf, 0, -1, false, diff_lines)
    pcall(vim.api.nvim_buf_set_option, changes_state.preview_buf, "filetype", "diff")
end

local function setup_changes_keymaps(results_buf)
    vim.keymap.set("n", "<CR>", function()
        if not changes_state.win or not vim.api.nvim_win_is_valid(changes_state.win) then return end
        local cursor = vim.api.nvim_win_get_cursor(changes_state.win)
        local line_num = cursor[1]
        if line_num >= 1 and line_num <= #changes_state.files then
            local file_info = changes_state.files[line_num]
            close_changes()
            vim.defer_fn(function()
                if file_info.file and file_info.file ~= "" then
                    pcall(vim.cmd, "edit " .. vim.fn.fnameescape(file_info.file))
                end
            end, 8)
        end
    end, { buffer = results_buf, silent = true })
    vim.keymap.set("n", "<Esc>", close_changes, { buffer = results_buf, silent = true })
    vim.keymap.set("n", "q", close_changes, { buffer = results_buf, silent = true })
    vim.keymap.set("n", "j", function()
        local cursor = vim.api.nvim_win_get_cursor(changes_state.win)
        if cursor[1] < #changes_state.files then
            vim.api.nvim_win_set_cursor(changes_state.win, { cursor[1] + 1, 0 })
            update_diff_preview()
        end
    end, { buffer = results_buf, silent = true })
    vim.keymap.set("n", "k", function()
        local cursor = vim.api.nvim_win_get_cursor(changes_state.win)
        if cursor[1] > 1 then
            vim.api.nvim_win_set_cursor(changes_state.win, { cursor[1] - 1, 0 })
            update_diff_preview()
        end
    end, { buffer = results_buf, silent = true })
end

local function setup_changes_autocmds(results_buf)
    vim.api.nvim_create_autocmd("WinClosed", {
        buffer = results_buf,
        once = true,
        callback = function()
            close_changes()
        end
    })
    vim.api.nvim_create_autocmd("CursorMoved", { buffer = results_buf, callback = update_diff_preview })
end

function Git.changes()
    if is_changes_valid_state() then
        close_changes()
        return
    end
    local files = get_changed_files()
    changes_state.files = files
    local ok_layout, layout = pcall(Window.create_layout, {
        width_ratio = 0.8,
        height_ratio = 0.7,
        preview_width_ratio = 0.6,
        results_title = string.format(" Changed Files (%d) ", #files),
        preview_title = " Diff Preview ",
        input_title = "",
        input_height = 1,
    })
    if not ok_layout then
        print("Failed to create changes windows: " .. tostring(layout))
        return
    end
    changes_state.buf = layout.results.buf
    changes_state.win = layout.results.win
    changes_state.preview_buf = layout.preview.buf
    changes_state.preview_win = layout.preview.win
    changes_state.is_open = true
    Window.safe_close_window(layout.input.win)
    Window.safe_delete_buffer(layout.input.buf)
    local display_lines = {}
    if #files == 0 then
        table.insert(display_lines, "No changes to display")
    else
        for _, file_info in ipairs(files) do
            table.insert(display_lines, file_info.display)
        end
    end
    vim.api.nvim_buf_set_lines(changes_state.buf, 0, -1, false, display_lines)
    setup_changes_keymaps(changes_state.buf)
    setup_changes_autocmds(changes_state.buf)
    vim.api.nvim_set_current_win(changes_state.win)
    if #files > 0 then
        pcall(vim.api.nvim_win_set_cursor, changes_state.win, { 1, 0 })
        update_diff_preview()
    end
end

local history_state = {
    buf = nil,
    win = nil,
    details_buf = nil,
    details_win = nil,
    diff_buf = nil,
    diff_win = nil,
    is_open = false,
    commits = {},
}

local function is_history_valid_state()
    return history_state.is_open and history_state.win and vim.api.nvim_win_is_valid(history_state.win)
end

local function reset_history_state()
    history_state.buf = nil
    history_state.win = nil
    history_state.details_buf = nil
    history_state.details_win = nil
    history_state.diff_buf = nil
    history_state.diff_win = nil
    history_state.is_open = false
    history_state.commits = {}
end

local function close_history()
    Window.safe_close_window(history_state.win)
    Window.safe_close_window(history_state.details_win)
    Window.safe_close_window(history_state.diff_win)
    Window.safe_delete_buffer(history_state.buf)
    Window.safe_delete_buffer(history_state.details_buf)
    Window.safe_delete_buffer(history_state.diff_buf)
    reset_history_state()
    vim.schedule(function()
        pcall(vim.cmd, "redraw!")
        pcall(vim.cmd, "mode")
    end)
end

local function get_commit_history(limit)
    limit = limit or 50
    local cmd = string.format("git log --pretty=format:'%%h|%%an|%%ar|%%s' -%d", limit)
    local ok, output = pcall(vim.fn.systemlist, cmd)
    if not ok or not output then return {} end
    local commits = {}
    for _, line in ipairs(output) do
        if line ~= "" then
            local parts = vim.split(line, "|", { plain = true })
            if #parts >= 4 then
                local hash = parts[1]
                local author = parts[2]
                local time = parts[3]
                local message = parts[4]
                if #author > 20 then
                    author = author:sub(1, 17) .. "..."
                end
                local display = string.format("%s  %s  %s  %s", hash, time, author, message)
                table.insert(commits, { hash = hash, author = author, time = time, message = message, display = display })
            end
        end
    end
    return commits
end

local function get_commit_details(hash)
    local cmd = string.format("git show --stat --pretty=format:'Commit: %%H%%nAuthor: %%an <%%ae>%%nDate: %%ar (%%ad)%%n%%nMessage: %%s%%n%%b%%n' %s", hash)
    local ok, output = pcall(vim.fn.systemlist, cmd)
    if not ok or not output then return { "Failed to load commit details" } end
    return output
end

local function get_commit_diff(hash)
    local cmd = string.format("git show --pretty=format:'' %s", hash)
    local ok, output = pcall(vim.fn.systemlist, cmd)
    if not ok or not output then return { "Failed to load commit diff" } end
    if #output > 0 and output[1] == "" then
        table.remove(output, 1)
    end
    if #output == 0 then
        return { "No changes in this commit" }
    end
    return output
end

local function update_commit_previews()
    if not history_state.details_buf or not vim.api.nvim_buf_is_valid(history_state.details_buf) then return end
    if not history_state.diff_buf or not vim.api.nvim_buf_is_valid(history_state.diff_buf) then return end
    if not history_state.buf or not vim.api.nvim_buf_is_valid(history_state.buf) then return end
    local cursor = vim.api.nvim_win_get_cursor(history_state.win)
    local line_num = cursor[1]
    if line_num < 1 or line_num > #history_state.commits then
        vim.api.nvim_buf_set_lines(history_state.details_buf, 0, -1, false, { "Commit details." })
        vim.api.nvim_buf_set_lines(history_state.diff_buf, 0, -1, false, { "Commit changes." })
        return
    end
    local commit_info = history_state.commits[line_num]
    if not commit_info or not commit_info.hash then
        vim.api.nvim_buf_set_lines(history_state.details_buf, 0, -1, false, { "Commit details." })
        vim.api.nvim_buf_set_lines(history_state.diff_buf, 0, -1, false, { "Commit changes." })
        return
    end
    local details = get_commit_details(commit_info.hash)
    vim.api.nvim_buf_set_lines(history_state.details_buf, 0, -1, false, details)
    pcall(vim.api.nvim_buf_set_option, history_state.details_buf, "filetype", "git")
    local diff = get_commit_diff(commit_info.hash)
    vim.api.nvim_buf_set_lines(history_state.diff_buf, 0, -1, false, diff)
    pcall(vim.api.nvim_buf_set_option, history_state.diff_buf, "filetype", "diff")
end

local function setup_history_keymaps(results_buf)
    vim.keymap.set("n", "<CR>", function()
        if not history_state.win or not vim.api.nvim_win_is_valid(history_state.win) then return end
        local cursor = vim.api.nvim_win_get_cursor(history_state.win)
        local line_num = cursor[1]
        if line_num >= 1 and line_num <= #history_state.commits then
            local commit_info = history_state.commits[line_num]
            vim.fn.setreg("+", commit_info.hash)
            vim.notify("Copied commit hash: " .. commit_info.hash, vim.log.levels.INFO)
        end
    end, { buffer = results_buf, silent = true })
    vim.keymap.set("n", "<Esc>", close_history, { buffer = results_buf, silent = true })
    vim.keymap.set("n", "q", close_history, { buffer = results_buf, silent = true })
    vim.keymap.set("n", "j", function()
        local cursor = vim.api.nvim_win_get_cursor(history_state.win)
        if cursor[1] < #history_state.commits then
            vim.api.nvim_win_set_cursor(history_state.win, { cursor[1] + 1, 0 })
            update_commit_previews()
        end
    end, { buffer = results_buf, silent = true })
    vim.keymap.set("n", "k", function()
        local cursor = vim.api.nvim_win_get_cursor(history_state.win)
        if cursor[1] > 1 then
            vim.api.nvim_win_set_cursor(history_state.win, { cursor[1] - 1, 0 })
            update_commit_previews()
        end
    end, { buffer = results_buf, silent = true })
end

local function setup_history_autocmds(results_buf)
    vim.api.nvim_create_autocmd("WinClosed", {
        buffer = results_buf,
        once = true,
        callback = function()
            close_history()
        end
    })
    vim.api.nvim_create_autocmd("CursorMoved", { buffer = results_buf,  callback = update_commit_previews })
end

local function create_three_panel_layout(opts)
    opts = opts or {}
    local width_ratio = opts.width_ratio or 0.9
    local height_ratio = opts.height_ratio or 0.8
    local left_width_ratio = opts.left_width_ratio or 0.30
    local middle_width_ratio = opts.middle_width_ratio or 0.35
    local total_width = math.floor(vim.o.columns * width_ratio)
    local total_height = math.floor(vim.o.lines * height_ratio)
    local row = math.floor((vim.o.lines - total_height) / 2)
    local col = math.floor((vim.o.columns - total_width) / 2)
    if total_width < 60 or total_height < 20 then
        error("Window too small for three-panel layout")
    end
    local left_width = math.floor(total_width * left_width_ratio)
    local middle_width = math.floor(total_width * middle_width_ratio)
    local right_width = total_width - left_width - middle_width - 2
    if left_width < 10 or middle_width < 10 or right_width < 10 then
        error("Panel dimensions too small")
    end
    local left_buf = vim.api.nvim_create_buf(false, true)
    local middle_buf = vim.api.nvim_create_buf(false, true)
    local right_buf = vim.api.nvim_create_buf(false, true)
    for _, buf in ipairs({ left_buf, middle_buf, right_buf }) do
        pcall(vim.api.nvim_buf_set_option, buf, "buftype", "nofile")
        pcall(vim.api.nvim_buf_set_option, buf, "bufhidden", "wipe")
        pcall(vim.api.nvim_buf_set_option, buf, "swapfile", false)
        pcall(vim.api.nvim_buf_set_option, buf, "buflisted", false)
    end
    local left_win = vim.api.nvim_open_win(left_buf, false, {
        relative = "editor",
        width = left_width,
        height = total_height,
        row = row,
        col = col,
        border = "single",
        style = "minimal",
        title = opts.left_title or " Left ",
        title_pos = "center"
    })
    pcall(vim.api.nvim_win_set_option, left_win, "winblend", 0)
    pcall(vim.api.nvim_set_option_value, "winhighlight", "Normal:Normal,FloatBorder:FloatBorder", { win = left_win })
    local middle_win = vim.api.nvim_open_win(middle_buf, false, {
        relative = "editor",
        width = middle_width,
        height = total_height,
        row = row,
        col = col + left_width + 1,
        border = "single",
        style = "minimal",
        title = opts.middle_title or " Middle ",
        title_pos = "center"
    })
    pcall(vim.api.nvim_win_set_option, middle_win, "winblend", 0)
    pcall(vim.api.nvim_set_option_value, "winhighlight", "Normal:Normal,FloatBorder:FloatBorder", { win = middle_win })
    local right_win = vim.api.nvim_open_win(right_buf, false, {
        relative = "editor",
        width = right_width,
        height = total_height,
        row = row,
        col = col + left_width + middle_width + 2,
        border = "single",
        style = "minimal",
        title = opts.right_title or " Right ",
        title_pos = "center"
    })
    pcall(vim.api.nvim_win_set_option, right_win, "winblend", 0)
    pcall(vim.api.nvim_set_option_value, "winhighlight", "Normal:Normal,FloatBorder:FloatBorder", { win = right_win })
    return { left = { buf = left_buf, win = left_win }, middle = { buf = middle_buf, win = middle_win }, right = { buf = right_buf, win = right_win } }
end

function Git.history()
    if is_history_valid_state() then
        close_history()
        return
    end
    local commits = get_commit_history(50)
    history_state.commits = commits
    local ok_layout, layout = pcall(create_three_panel_layout, {
        width_ratio = 0.95,
        height_ratio = 0.80,
        left_width_ratio = 0.30,
        middle_width_ratio = 0.35,
        left_title = string.format(" Commits (%d) ", #commits),
        middle_title = " Commit Details ",
        right_title = " Changes ",
    })
    if not ok_layout then
        print("Failed to create history windows: " .. tostring(layout))
        return
    end
    history_state.buf = layout.left.buf
    history_state.win = layout.left.win
    history_state.details_buf = layout.middle.buf
    history_state.details_win = layout.middle.win
    history_state.diff_buf = layout.right.buf
    history_state.diff_win = layout.right.win
    history_state.is_open = true
    local display_lines = {}
    if #commits == 0 then
        table.insert(display_lines, "No commit history found")
    else
        for _, commit_info in ipairs(commits) do
            table.insert(display_lines, commit_info.display)
        end
    end
    vim.api.nvim_buf_set_lines(history_state.buf, 0, -1, false, display_lines)
    setup_history_keymaps(history_state.buf)
    setup_history_autocmds(history_state.buf)
    vim.api.nvim_set_current_win(history_state.win)
    if #commits > 0 then
        pcall(vim.api.nvim_win_set_cursor, history_state.win, { 1, 0 })
        update_commit_previews()
    end
end

return Git
