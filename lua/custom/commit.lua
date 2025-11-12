local Commit = {}

local commit_types = { "feat", "fix", "docs", "style", "refactor", "perf", "test", "chore" }

local state = {
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
    return buf, win
end

local function update_display(buf, win)
    vim.bo[buf].modifiable = true
    local lines = {
        "╭─────────────────────────────────────────────────────────────────╮",
        string.format("│ Type: %-58s │", state.type),
        string.format("│ Scope: %-57s │", state.scope),
        string.format("│ Message: %-55s │", state.message),
        "╰─────────────────────────────────────────────────────────────────╯",
        "",
        "Instructions:",
        "  [1] Select Type    [2] Edit Scope    [3] Edit Message",
        "  <Enter> Commit     <C-c> Cancel",
    }
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    local commit_scope = state.scope ~= "" and ("(" .. state.scope .. ")") or ""
    local preview = string.format("Preview: %s%s: %s", state.type, commit_scope, state.message)
    print(preview)
end

local function setup_keymaps(buf, win)
    vim.keymap.set("n", "1", function()
        vim.ui.select(commit_types, {
            prompt = "Select commit type:",
            format_item = function(item) return "  " .. item end,
        }, function(choice)
            if choice then
                state.type = choice
                print("Selected type: " .. choice)
                update_display(buf, win)
            end
        end)
    end, { buffer = buf, silent = true })
    vim.keymap.set("n", "2", function()
        vim.ui.input({
            prompt = "Scope (optional): ",
            default = state.scope
        }, function(input)
            if input ~= nil then
                state.scope = input
                print("Scope set to: " .. (input ~= "" and input or "(empty)"))
                update_display(buf, win)
            end
        end)
    end, { buffer = buf, silent = true })
    vim.keymap.set("n", "3", function()
        vim.ui.input({
            prompt = "Commit message: ",
            default = state.message
        }, function(input)
            if input then
                state.message = input
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
        if state.type == "" then
            vim.notify("Please select a commit type", vim.log.levels.WARN)
            return
        end
        if state.message == "" then
            vim.notify("Please enter a commit message", vim.log.levels.WARN)
            return
        end
        local commit_scope = state.scope ~= "" and ("(" .. state.scope .. ")") or ""
        local commit_text = string.format("%s%s: %s", state.type, commit_scope, state.message)
        vim.api.nvim_win_close(win, true)
        print("Staging and committing: " .. commit_text)
        vim.notify("Staging changes...", vim.log.levels.INFO)
        -- First stage all changes
        vim.fn.jobstart({ "git", "add", "-A" }, {
            on_exit = function(_, stage_code)
                if stage_code == 0 then
                    -- Then commit
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
                                print("✓ Commit successful!")
                                vim.notify("Commit successful!", vim.log.levels.INFO)
                                state.type = ""
                                state.scope = ""
                                state.message = ""
                            else
                                print("✗ Commit failed")
                                vim.notify("Commit failed", vim.log.levels.ERROR)
                            end
                        end,
                    })
                else
                    vim.notify("Failed to stage changes", vim.log.levels.ERROR)
                end
            end,
        })
    end, { buffer = buf, silent = true })
end

function Commit.open()
    state.type = ""
    state.scope = ""
    state.message = ""
    print("\nGit Commit")
    local buf, win = create_float("Git Commit", 70, 11)
    update_display(buf, win)
    setup_keymaps(buf, win)
end

return Commit
