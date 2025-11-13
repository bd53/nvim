local Window = require("custom.window")
local Git = {}

local blame_config = { namespace = vim.api.nvim_create_namespace("git_blame") }
local blame_state = { timer = nil, last_line = nil, enabled = false }
local commit_types = { "feat", "tweak", "fix", "docs", "style", "refactor", "perf", "test", "chore" }
local commit_state = { type = "", scope = "", message = "", description = "" }
local commit_window_state = { buf = nil, win = nil, is_open = false }

local function gen_state()
    return {
        buf = nil,
        win = nil,
        preview_buf = nil,
        preview_win = nil,
        details_buf = nil,
        details_win = nil,
        is_open = false,
        items = {},
    }
end

local changes_state = gen_state()
local history_state = gen_state()

local function run_git_cmd(cmd)
    local ok, output = pcall(vim.fn.systemlist, cmd)
    if ok and output and #output > 0 then return output end
    return nil
end

local function relative_time(ts)
    if not ts then return "just now" end
    local diff = os.time() - ts
    local intervals = { { 365 * 86400, "y" }, { 30 * 86400, "mo" }, { 86400, "d" }, { 3600, "h" }, { 60, "m" } }
    for _, interval in ipairs(intervals) do
        local value = math.floor(diff / interval[1])
        if value > 0 then return value .. interval[2] .. " ago" end
    end
    return "just now"
end

local function short_display(text, max_len)
    if #text > max_len then return text:sub(1, max_len - 3) .. "..." end
    return text
end

local function git_job(cmd, callback)
    vim.fn.jobstart(cmd, { stdout_buffered = true, stderr_buffered = true, on_stdout = callback, on_stderr = callback })
end

local function is_valid_state(state)
    return state.is_open and state.win and vim.api.nvim_win_is_valid(state.win)
end

local function reset_state(state)
    for k in pairs(state) do
        if k == "is_open" then state[k] = false return end
        if k == "items" then state[k] = {} return end
        state[k] = nil
    end
end

local function close_view(state)
    Window.safe_close_window(state.win)
    Window.safe_close_window(state.preview_win)
    Window.safe_close_window(state.details_win)
    Window.safe_close_window(state.diff_win)
    Window.safe_delete_buffer(state.buf)
    Window.safe_delete_buffer(state.preview_buf)
    Window.safe_delete_buffer(state.details_buf)
    Window.safe_delete_buffer(state.diff_buf)
    reset_state(state)
    vim.schedule(function()
        pcall(vim.cmd, "redraw!")
        pcall(vim.cmd, "mode")
    end)
end

local function get_cursor_item(state)
    if not state.win or not vim.api.nvim_win_is_valid(state.win) then return nil end
    local cursor = vim.api.nvim_win_get_cursor(state.win)
    local line_num = cursor[1]
    if line_num >= 1 and line_num <= #state.items then return state.items[line_num], line_num end
    return nil, nil
end

local function setup_navigation_keymaps(buf, state, update_callback)
    local close_fn = function() close_view(state) end
    vim.keymap.set("n", "<Esc>", close_fn, { buffer = buf, silent = true })
    vim.keymap.set("n", "q", close_fn, { buffer = buf, silent = true })
    vim.keymap.set("n", "j", function()
        local cursor = vim.api.nvim_win_get_cursor(state.win)
        if cursor[1] < #state.items then
            vim.api.nvim_win_set_cursor(state.win, { cursor[1] + 1, 0 })
            if update_callback then update_callback() end
        end
    end, { buffer = buf, silent = true })
    vim.keymap.set("n", "k", function()
        local cursor = vim.api.nvim_win_get_cursor(state.win)
        if cursor[1] > 1 then
            vim.api.nvim_win_set_cursor(state.win, { cursor[1] - 1, 0 })
            if update_callback then update_callback() end
        end
    end, { buffer = buf, silent = true })
end

local function setup_close_autocmd(buf, state)
    vim.api.nvim_create_autocmd("WinClosed", {
      buffer = buf,
      once = true,
      callback = function()
        close_view(state)
      end
    })
end

local function get_blame(line)
    local file = vim.fn.expand("%:p")
    if file == "" then return nil end
    local output = run_git_cmd(string.format("git --no-pager blame -L %d,%d --porcelain '%s'", line, line, file))
    if not output then return nil end
    local commit = output[1]:match("^(%w+)")
    if commit == "0000000000000000000000000000000000000000" then return nil end
    local author, timestamp, summary
    for _, l in ipairs(output) do
        if l:find("^author ") then author = l:sub(8) end
        if l:find("^author-time ") then timestamp = tonumber(l:sub(13)) end
        if l:find("^summary ") then summary = l:sub(9) end
    end
    return { commit = commit:sub(1, 7), author = author, time = relative_time(timestamp), summary = summary }
end

local function clear_blame() vim.api.nvim_buf_clear_namespace(0, blame_config.namespace, 0, -1) end

local function show_blame(line, blame)
    clear_blame()
    if not blame then return end
    local author = short_display(blame.author or "?", 20)
    local text = string.format("%s (%s) %s - %s", blame.commit or "?", blame.time or "?", author, blame.summary or "?")
    vim.api.nvim_buf_set_extmark(0, blame_config.namespace, line - 1, 0, { virt_text = { { text, "Comment" } }, virt_text_pos = "eol" })
end

local function update_blame()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    if row == blame_state.last_line then return end
    blame_state.last_line = row
    show_blame(row, get_blame(row))
end

local function schedule_update()
    blame_state.timer = vim.defer_fn(function()
        pcall(update_blame)
    end, 100)
end

local function setup_blame_autocmds()
    vim.cmd("highlight link GitBlameVirtText Comment")
    local group = vim.api.nvim_create_augroup("GitBlame", { clear = true })
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
      group = group,
      callback = schedule_update,
    })
    vim.api.nvim_create_autocmd({ "BufLeave", "InsertEnter" }, {
      group = group,
      callback = clear_blame,
    })
    vim.api.nvim_create_autocmd("BufEnter", {
        group = group,
        callback = function()
            blame_state.last_line = nil
            schedule_update()
        end
    })
    vim.schedule(schedule_update)
end

function Git.toggle()
    blame_state.enabled = not blame_state.enabled
    if not blame_state.enabled then
        blame_state.timer = nil
        clear_blame()
        vim.api.nvim_clear_autocmds({ group = "GitBlame" })
        blame_state.last_line = nil
        vim.notify("Git blame: disabled", vim.log.levels.WARN)
        return
    end
    setup_blame_autocmds()
    vim.notify("Git blame: enabled", vim.log.levels.WARN)
end

local function update_commit_display(buf)
    vim.bo[buf].modifiable = true
    local desc_first_line = commit_state.description:gsub("\n.*", "")
    local desc_display = short_display(desc_first_line, 51)
    local lines = {
        "╭" .. string.rep("─", 65) .. "╮",
        string.format("│ Type: %-58s │", commit_state.type),
        string.format("│ Scope: %-57s │", commit_state.scope),
        string.format("│ Message: %-55s │", commit_state.message),
        string.format("│ Description: %-51s │", desc_display),
        "╰" .. string.rep("─", 65) .. "╯",
        "  [1] Type [2] Scope [3] Message [4] Description",
    }
    local preview = ""
    if commit_state.type ~= "" and commit_state.message ~= "" then
        preview = commit_state.type .. (commit_state.scope ~= "" and "(" .. commit_state.scope .. ")" or "") .. ": " .. commit_state.message
        if commit_state.description ~= "" then
            preview = preview .. "\n\n" .. commit_state.description
        end
    end
    if preview ~= "" then
        table.insert(lines, "")
        for i, line in ipairs(vim.split(preview, "\n", { plain = true })) do
            table.insert(lines, (i == 1 and "  Preview: " or " ") .. line)
        end
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
end

local function do_push()
    vim.notify("Pushing to remote...", vim.log.levels.INFO)
    git_job({ "git", "push" }, function(_, data)
        if data and data[1] ~= "" then
            vim.notify(table.concat(data, "\n"), vim.log.levels.INFO)
        end
    end)
end

local function do_commit(win, should_push)
    if commit_state.type == "" or commit_state.message == "" then vim.notify("Please fill in type and message.", vim.log.levels.WARN) return end
    local text = commit_state.type .. (commit_state.scope ~= "" and "(" .. commit_state.scope .. ")" or "") .. ": " .. commit_state.message
    if commit_state.description ~= "" then
      text = text .. "\n\n" .. commit_state.description
    end
    vim.api.nvim_win_close(win, true)
    commit_window_state.buf = nil
    commit_window_state.win = nil
    commit_window_state.is_open = false
    vim.notify("Staging and committing: " .. text:gsub("\n.*", "..."), vim.log.levels.INFO)
    vim.fn.jobstart({ "git", "add", "-A" }, {
        on_exit = function(_, code)
            if code ~= 0 then vim.notify("Staging failed.", vim.log.levels.ERROR) return end
            vim.fn.jobstart({ "git", "commit", "-m", text }, {
                stdout_buffered = true,
                stderr_buffered = true,
                on_stdout = function(_, data)
                    if data then
                        vim.notify("Git output: " .. table.concat(data, "\n"), vim.log.levels.INFO)
                    end
                end,
                on_stderr = function(_, data)
                    if data then
                        vim.notify("Git error: " .. table.concat(data, "\n"), vim.log.levels.ERROR)
                    end
                end,
                on_exit = function(_, c)
                    if c == 0 then
                        vim.notify("Commit succeeded: " .. text:gsub("\n.*", "..."), vim.log.levels.INFO)
                        if should_push then do_push() end
                    else
                        vim.notify("Commit failed.", vim.log.levels.ERROR)
                    end
                end,
            })
        end,
    })
end

local function setup_commit_keymaps(buf, win)
    local close_fn = function()
        Window.safe_close_window(win)
        commit_window_state.buf = nil
        commit_window_state.win = nil
        commit_window_state.is_open = false
        vim.notify("Commit cancelled.", vim.log.levels.WARN)
    end
    local mappings = {
        ["1"] = function()
            Window.create_select({
                title = " Type ",
                items = commit_types,
                callback = function(choice)
                    if choice then
                        commit_state.type = choice
                        update_commit_display(buf)
                    end
                end,
                parent_win = win
            })
        end,
        ["2"] = function()
            Window.create_input({
                title = " Scope (optional) ",
                default_text = commit_state.scope,
                callback = function(input)
                    if input ~= nil then
                        commit_state.scope = input
                        update_commit_display(buf)
                    end
                end,
                parent_win = win
            })
        end,
        ["3"] = function()
            Window.create_input({
                title = " Message ",
                default_text = commit_state.message,
                callback = function(input)
                    if input and input ~= "" then
                        commit_state.message = input
                        update_commit_display(buf)
                    end
                end,
                parent_win = win
            })
        end,
        ["4"] = function()
            Window.create_input({
                title = " Description (optional) ",
                default_text = commit_state.description,
                callback = function(input)
                    if input ~= nil then
                        commit_state.description = input
                        update_commit_display(buf)
                    end
                end,
                parent_win = win
            })
        end,
        ["<Esc>"] = close_fn,
        ["q"] = close_fn,
        ["<C-c>"] = close_fn,
        ["<CR>"] = function() do_commit(win, false) end,
    }
    for key, fn in pairs(mappings) do
        vim.keymap.set("n", key, fn, { buffer = buf, silent = true })
    end
end

function Git.commit()
    if commit_window_state.is_open and commit_window_state.win and vim.api.nvim_win_is_valid(commit_window_state.win) then
        Window.safe_close_window(commit_window_state.win)
        Window.safe_delete_buffer(commit_window_state.buf)
        commit_window_state.buf = nil
        commit_window_state.win = nil
        commit_window_state.is_open = false
        vim.notify("Commit cancelled.", vim.log.levels.WARN)
        return
    end
    commit_state = { type = "", scope = "", message = "", description = "" }
    local buf, win = Window.create_float({
        title = " Commit ",
        width = 70,
        height = 16,
        border = "rounded"
    })
    commit_window_state.buf = buf
    commit_window_state.win = win
    commit_window_state.is_open = true
    vim.bo[buf].modifiable = false
    update_commit_display(buf)
    setup_commit_keymaps(buf, win)
    vim.api.nvim_create_autocmd("WinClosed", {
        buffer = buf,
        once = true,
        callback = function()
            commit_window_state.buf = nil
            commit_window_state.win = nil
            commit_window_state.is_open = false
        end
    })
end

function Git.push() do_push() end

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

local function get_changed_files()
    local output = run_git_cmd("git status --porcelain")
    if not output then return {} end
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
    local staged_diff = run_git_cmd(string.format("git diff --cached -- '%s'", file))
    local unstaged_diff = run_git_cmd(string.format("git diff -- '%s'", file))
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
        local content = run_git_cmd(string.format("git show HEAD:'%s' 2>/dev/null || cat '%s'", file, file))
        if content then
            table.insert(lines, "=== NEW FILE ===")
            table.insert(lines, "")
            vim.list_extend(lines, content)
        end
    end
    return #lines == 0 and { "No changes to display." } or lines
end

local function update_changes_preview()
    if not changes_state.preview_buf or not vim.api.nvim_buf_is_valid(changes_state.preview_buf) then return end
    local item, _ = get_cursor_item(changes_state)
    if not item or not item.file then vim.api.nvim_buf_set_lines(changes_state.preview_buf, 0, -1, false, { "No changes to display." }) return end
    local diff_lines = get_file_diff(item.file)
    vim.api.nvim_buf_set_lines(changes_state.preview_buf, 0, -1, false, diff_lines)
    pcall(vim.api.nvim_buf_set_option, changes_state.preview_buf, "filetype", "diff")
end

local function setup_changes_keymaps(buf)
    vim.keymap.set("n", "<CR>", function()
        local item, _ = get_cursor_item(changes_state)
        if item and item.file and item.file ~= "" then
            close_view(changes_state)
            vim.defer_fn(function()
                pcall(vim.cmd, "edit " .. vim.fn.fnameescape(item.file))
            end, 8)
        end
    end, { buffer = buf, silent = true })
    setup_navigation_keymaps(buf, changes_state, update_changes_preview)
end

function Git.changes()
    if is_valid_state(changes_state) then close_view(changes_state) return end
    local files = get_changed_files()
    changes_state.items = files
    local ok_layout, layout = pcall(Window.create_split_two, {
        width_ratio = 0.8,
        height_ratio = 0.7,
        preview_width_ratio = 0.6,
        results_title = string.format(" Changed Files (%d) ", #files),
        preview_title = " Diff Preview ",
        input_title = "",
        input_height = 1,
    })
    if not ok_layout then vim.notify(("Failed to create changes windows: %s"):format(tostring(layout)), vim.log.levels.ERROR) return end
    changes_state.buf = layout.results.buf
    changes_state.win = layout.results.win
    changes_state.preview_buf = layout.preview.buf
    changes_state.preview_win = layout.preview.win
    changes_state.is_open = true
    Window.safe_close_window(layout.input.win)
    Window.safe_delete_buffer(layout.input.buf)
    local display_lines = #files == 0 and { "No changes to display." } or vim.tbl_map(function(f) return f.display end, files)
    vim.api.nvim_buf_set_lines(changes_state.buf, 0, -1, false, display_lines)
    setup_changes_keymaps(changes_state.buf)
    setup_close_autocmd(changes_state.buf, changes_state)
    vim.api.nvim_create_autocmd("CursorMoved", {
      buffer = changes_state.buf,
      callback = update_changes_preview,
    })
    vim.api.nvim_set_current_win(changes_state.win)
    if #files > 0 then
        pcall(vim.api.nvim_win_set_cursor, changes_state.win, { 1, 0 })
        update_changes_preview()
    end
end

local function get_commit_history(limit)
    limit = limit or 50
    local output = run_git_cmd(string.format("git log --pretty=format:'%%h|%%an|%%ar|%%s' -%d", limit))
    if not output then return {} end
    local commits = {}
    for _, line in ipairs(output) do
        if line ~= "" then
            local parts = vim.split(line, "|", { plain = true })
            if #parts >= 4 then
                local hash, author, time, message = parts[1], parts[2], parts[3], parts[4]
                author = short_display(author, 20)
                local display = string.format("%s  %s  %s  %s", hash, time, author, message)
                table.insert(commits, { hash = hash, author = author, time = time, message = message, display = display })
            end
        end
    end
    return commits
end

local function get_commit_details(hash)
    local output = run_git_cmd(string.format("git show --stat --pretty=format:'Commit: %%H%%nAuthor: %%an <%%ae>%%nDate: %%ar (%%ad)%%n%%nMessage: %%s%%n%%b%%n' %s", hash))
    return output or { "Failed to load commit details." }
end

local function get_commit_diff(hash)
    local output = run_git_cmd(string.format("git show --pretty=format:'' %s", hash))
    if not output then return { "Failed to load commit diff." } end
    if #output > 0 and output[1] == "" then
        table.remove(output, 1)
    end
    return #output == 0 and { "No changes in this commit." } or output
end

local function update_history_previews()
    if not history_state.details_buf or not vim.api.nvim_buf_is_valid(history_state.details_buf) then return end
    if not history_state.diff_buf or not vim.api.nvim_buf_is_valid(history_state.diff_buf) then return end
    local item, _ = get_cursor_item(history_state)
    if not item or not item.hash then
        vim.api.nvim_buf_set_lines(history_state.details_buf, 0, -1, false, { "Commit details." })
        vim.api.nvim_buf_set_lines(history_state.diff_buf, 0, -1, false, { "Commit changes." })
        return
    end
    local details = get_commit_details(item.hash)
    vim.api.nvim_buf_set_lines(history_state.details_buf, 0, -1, false, details)
    pcall(vim.api.nvim_buf_set_option, history_state.details_buf, "filetype", "git")
    local diff = get_commit_diff(item.hash)
    vim.api.nvim_buf_set_lines(history_state.diff_buf, 0, -1, false, diff)
    pcall(vim.api.nvim_buf_set_option, history_state.diff_buf, "filetype", "diff")
end

local function setup_history_keymaps(buf)
    vim.keymap.set("n", "<CR>", function()
        local item, _ = get_cursor_item(history_state)
        if item and item.hash then
            vim.fn.setreg("+", item.hash)
            vim.notify("Copied commit hash: " .. item.hash, vim.log.levels.INFO)
        end
    end, { buffer = buf, silent = true })
    setup_navigation_keymaps(buf, history_state, update_history_previews)
end

function Git.history()
    if is_valid_state(history_state) then close_view(history_state) return end
    local commits = get_commit_history(50)
    history_state.items = commits
    local ok_layout, layout = pcall(Window.create_split_three, {
        width_ratio = 0.95,
        height_ratio = 0.80,
        left_width_ratio = 0.30,
        middle_width_ratio = 0.35,
        left_title = string.format(" Commits (%d) ", #commits),
        middle_title = " Commit Details ",
        right_title = " Changes ",
    })
    if not ok_layout then vim.notify(("Failed to create history windows: %s"):format(tostring(layout)), vim.log.levels.ERROR) return end
    history_state.buf = layout.left.buf
    history_state.win = layout.left.win
    history_state.details_buf = layout.middle.buf
    history_state.details_win = layout.middle.win
    history_state.diff_buf = layout.right.buf
    history_state.diff_win = layout.right.win
    history_state.is_open = true
    local display_lines = #commits == 0 and { "No commit history found." } or vim.tbl_map(function(c) return c.display end, commits)
    vim.api.nvim_buf_set_lines(history_state.buf, 0, -1, false, display_lines)
    setup_history_keymaps(history_state.buf)
    setup_close_autocmd(history_state.buf, history_state)
    vim.api.nvim_create_autocmd("CursorMoved", {
      buffer = history_state.buf,
      callback = update_history_previews,
    })
    vim.api.nvim_set_current_win(history_state.win)
    if #commits > 0 then
        pcall(vim.api.nvim_win_set_cursor, history_state.win, { 1, 0 })
        update_history_previews()
    end
end

return Git
