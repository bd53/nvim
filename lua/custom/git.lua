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
}

local function create_float(title, width, height)
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        col = (vim.o.columns - width) / 2,
        row = (vim.o.lines - height) / 2,
        style = "minimal",
        border = "rounded",
        title = title or "Commit",
        title_pos = "center",
    })
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].modifiable = false
    pcall(vim.api.nvim_win_set_option, win, "winblend", 0)
    pcall(vim.api.nvim_set_option_value, "winhighlight", "Normal:Normal,FloatBorder:FloatBorder", { win = win })
    return buf, win
end

local function update_display(buf, win)
    vim.bo[buf].modifiable = true
    local lines = {
        "╭─────────────────────────────────────────────────────────────────╮",
        string.format("│ Type: %-58s │", commit_state.type),
        string.format("│ Scope: %-57s │", commit_state.scope),
        string.format("│ Message: %-55s │", commit_state.message),
        "╰─────────────────────────────────────────────────────────────────╯",
        "",
        "  [1] Select Type    [2] Edit Scope    [3] Edit Message",
    }
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    local commit_scope = commit_state.scope ~= "" and ("(" .. commit_state.scope .. ")") or ""
    local preview = string.format("Preview: %s%s: %s", commit_state.type, commit_scope, commit_state.message)
    print(preview)
end

local function do_push()
    vim.notify("Pushing to remote...", vim.log.levels.INFO)
    vim.fn.jobstart({ "git", "push" }, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data)
            if data and data[1] ~= "" then
                local output = table.concat(data, "\n")
                print(output)
            end
        end,
        on_stderr = function(_, data)
            if data and data[1] ~= "" then
                local output = table.concat(data, "\n")
                print(output)
            end
        end,
        on_exit = function(_, code)
            if code == 0 then
                print("Push successful!")
                vim.notify("Push successful.", vim.log.levels.INFO)
            else
                print("Push failed")
                vim.notify("Push failed - check git output", vim.log.levels.ERROR)
            end
        end,
    })
end

local function do_commit(win, should_push)
    if commit_state.type == "" then
        vim.notify("Please select a commit type", vim.log.levels.WARN)
        return
    end
    if commit_state.message == "" then
        vim.notify("Please enter a commit message", vim.log.levels.WARN)
        return
    end
    local commit_scope = commit_state.scope ~= "" and ("(" .. commit_state.scope .. ")") or ""
    local commit_text = string.format("%s%s: %s", commit_state.type, commit_scope, commit_state.message)
    vim.api.nvim_win_close(win, true)
    print("Staging and committing: " .. commit_text)
    vim.notify("Staging changes...", vim.log.levels.INFO)
    vim.fn.jobstart({ "git", "add", "-A" }, {
        on_exit = function(_, stage_code)
            if stage_code == 0 then
                vim.fn.jobstart({ "git", "commit", "-m", commit_text }, {
                    stdout_buffered = true,
                    stderr_buffered = true,
                    on_stdout = function(_, data)
                        if data and data[1] ~= "" then
                            local output = table.concat(data, "\n")
                            print(output)
                            vim.notify(output, vim.log.levels.INFO)
                        end
                    end,
                    on_stderr = function(_, data)
                        if data and data[1] ~= "" then
                            local output = table.concat(data, "\n")
                            print(output)
                            vim.notify(output, vim.log.levels.ERROR)
                        end
                    end,
                    on_exit = function(_, code)
                        if code == 0 then
                            print("Commit successful!")
                            vim.notify("Commit successful!", vim.log.levels.INFO)
                            commit_state.type = ""
                            commit_state.scope = ""
                            commit_state.message = ""
                            if should_push then
                                do_push()
                            end
                        else
                            print("Commit failed")
                            vim.notify("Commit failed", vim.log.levels.ERROR)
                        end
                    end,
                })
            else
                vim.notify("Failed to stage changes", vim.log.levels.ERROR)
            end
        end,
    })
end

local function setup_keymaps(buf, win)
    vim.keymap.set("n", "1", function()
        vim.ui.select(commit_types, {
            prompt = "Select commit type:",
            format_item = function(item) return "  " .. item end,
        }, function(choice)
            if choice then
                commit_state.type = choice
                print("Selected type: " .. choice)
                update_display(buf, win)
            end
        end)
    end, { buffer = buf, silent = true })
    vim.keymap.set("n", "2", function()
        vim.ui.input({
            prompt = "Scope (optional): ",
            default = commit_state.scope
        }, function(input)
            if input ~= nil then
                commit_state.scope = input
                print("Scope set to: " .. (input ~= "" and input or "(empty)"))
                update_display(buf, win)
            end
        end)
    end, { buffer = buf, silent = true })
    vim.keymap.set("n", "3", function()
        vim.ui.input({
            prompt = "Commit message: ",
            default = commit_state.message
        }, function(input)
            if input then
                commit_state.message = input
                print("Message set to: " .. input)
                update_display(buf, win)
            end
        end)
    end, { buffer = buf, silent = true })
    vim.keymap.set("n", "<C-c>", function()
        vim.api.nvim_win_close(win, true)
        print("Commit cancelled")
        vim.notify("Commit cancelled", vim.log.levels.WARN)
    end, { buffer = buf, silent = true })
    vim.keymap.set("n", "<CR>", function()
        do_commit(win, false)
    end, { buffer = buf, silent = true })
end

function Git.commit()
    commit_state.type = ""
    commit_state.scope = ""
    commit_state.message = ""
    print("\nGit Commit")
    local buf, win = create_float("Git Commit", 70, 11)
    update_display(buf, win)
    setup_keymaps(buf, win)
end

function Git.push()
    do_push()
end

return Git
