local GitBlame = {}

local config = {
    namespace = vim.api.nvim_create_namespace("git_blame"),
    update_delay = 500,
}

local state = { timer = nil, last_line = nil, enabled = false }

local function get_blame(line)
    local file = vim.fn.expand("%:p")
    if file == "" then return nil end
    local cmd = string.format("git --no-pager blame -L %d,%d --porcelain '%s'", line, line, file)
    local ok, output = pcall(vim.fn.systemlist, cmd)
    if not ok or not output or #output == 0 then return nil end
    local commit = output[1]:match("^(%w+)")
    if commit == "0000000000000000000000000000000000000000" then return nil end
    local author, timestamp, summary
    for _, l in pairs(output) do
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
    vim.api.nvim_buf_clear_namespace(0, config.namespace, 0, -1)
end

local function show_blame(line, blame)
    clear_blame()
    if not blame then return end
    local author = blame.author or "?"
    if #author > 20 then
        author = author:sub(1, 17) .. "..."
    end
    local text = string.format("%s (%s) %s - %s", blame.commit or "?", blame.time or "?", author, blame.summary or "?")
    vim.api.nvim_buf_set_extmark(0, config.namespace, line - 1, 0, { virt_text = { { text, "Comment" } }, virt_text_pos = "eol" })
end

local function update_blame()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    if row == state.last_line then return end
    state.last_line = row
    local blame = get_blame(row)
    show_blame(row, blame)
end

local function schedule_update()
    state.timer = vim.defer_fn(function()
        local ok = pcall(update_blame)
        if not ok then clear_blame() end
    end, config.update_delay)
end

local function setup_autocmds()
    vim.cmd("highlight link GitBlameVirtText Comment")
    local group = vim.api.nvim_create_augroup("GitBlame", { clear = true })
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, { group = group, callback = schedule_update })
    vim.api.nvim_create_autocmd({ "BufLeave", "InsertEnter" }, { group = group, callback = clear_blame })
    vim.api.nvim_create_autocmd("BufEnter", {
        group = group,
        callback = function()
            state.last_line = nil
            schedule_update()
        end,
    })
    vim.schedule(function()
        state.last_line = nil
        schedule_update()
    end)
end

function GitBlame.toggle()
    state.enabled = not state.enabled
    if state.enabled then
        setup_autocmds()
        print("Git blame: enabled")
        return
    end
    if state.timer then
        state.timer = nil
    end
    clear_blame()
    vim.api.nvim_clear_autocmds({ group = "GitBlame" })
    state.last_line = nil
    print("Git blame: disabled")
end

return GitBlame
