local XP = {}

local data_file = vim.fn.stdpath("config") .. "/data.json"

local xp_data = {
  xp = 0,
  level = 1,
  xp_to_next = 100,
  total_xp = 0,
  achievements = {},
  stats = {
    files_saved = 0,
    chars_typed = 0,
    lines_added = 0,
    sessions = 0,
    streak_days = 0,
    last_play_date = "",
  },
  session = {
    start_time = 0,
    xp_this_session = 0,
    saves_this_session = 0,
    last_save_time = 0,
    last_type_time = 0,
  }
}

local achievements = {
  first_save = { name = "First Steps", desc = "Save your first file" },
  save_10 = { name = "Persistent", desc = "Save 10 files" },
  save_100 = { name = "Archiver", desc = "Save 100 files" },
  level_5 = { name = "Rising Star", desc = "Reach level 5" },
  level_10 = { name = "Pro Coder", desc = "Reach level 10" },
  level_25 = { name = "Master", desc = "Reach level 25" },
  level_50 = { name = "Legend", desc = "Reach level 50" },
  chars_1000 = { name = "Wordsmith", desc = "Type 1000 characters" },
  chars_10000 = { name = "Author", desc = "Type 10000 characters" },
  streak_7 = { name = "Week Warrior", desc = "Code 7 days in a row" },
  streak_30 = { name = "Monthly Master", desc = "Code 30 days in a row" },
  session_30min = { name = "Focused", desc = "Code for 30 minutes" },
  session_2hr = { name = "Marathon", desc = "Code for 2 hours" },
}

local function load_data()
  local f = io.open(data_file, "r")
  if not f then return end
  local ok, decoded = pcall(vim.fn.json_decode, f:read("*a"))
  f:close()
  if ok and decoded then
    xp_data = vim.tbl_deep_extend("force", xp_data, decoded)
  end
  xp_data.session = { start_time = os.time(), xp_this_session = 0, saves_this_session = 0, last_save_time = 0, last_type_time = 0 }
end

local save_timer = nil

local function save_data()
  if save_timer then
    save_timer:stop()
    save_timer:close()
    save_timer = nil
  end
  save_timer = vim.loop.new_timer()
  save_timer:start(100, 0, vim.schedule_wrap(function()
    local ok, err = pcall(function()
      local f = io.open(data_file, "w")
      if not f then return end
      f:write(vim.fn.json_encode(xp_data))
      f:close()
    end)
    if not ok then
      vim.print("XP save error: " .. tostring(err))
    end
    if save_timer then
      save_timer:stop()
      save_timer:close()
      save_timer = nil
    end
  end))
end

local function notify(msg, level)
  local has_notify, n = pcall(require, "notify")
  if has_notify then
    n(msg, level or vim.log.levels.INFO, { title = "XP System", timeout = 3000 })
  else
    vim.notify(msg, level or vim.log.levels.INFO)
  end
end

local function check_achievement(key)
  if xp_data.achievements[key] then return false end
  local ach = achievements[key]
  if not ach then return false end
  xp_data.achievements[key] = true
  local msg = string.format("ACHIEVEMENT UNLOCKED!\n%s\n%s", ach.name, ach.desc)
  notify(msg, vim.log.levels.WARN)
  add_xp(50, true)
  vim.schedule(save_data)
  return true
end

local function check_achievements()
  local stats = xp_data.stats
  local level = xp_data.level
  if stats.files_saved >= 1 then check_achievement("first_save") end
  if stats.files_saved >= 10 then check_achievement("save_10") end
  if stats.files_saved >= 100 then check_achievement("save_100") end
  if level >= 5 then check_achievement("level_5") end
  if level >= 10 then check_achievement("level_10") end
  if level >= 25 then check_achievement("level_25") end
  if level >= 50 then check_achievement("level_50") end
  if stats.chars_typed >= 1000 then check_achievement("chars_1000") end
  if stats.chars_typed >= 10000 then check_achievement("chars_10000") end
  if stats.streak_days >= 7 then check_achievement("streak_7") end
  if stats.streak_days >= 30 then check_achievement("streak_30") end
  local session_time = os.time() - xp_data.session.start_time
  if session_time >= 1800 then check_achievement("session_30min") end
  if session_time >= 7200 then check_achievement("session_2hr") end
end

function add_xp(amount, skip_cooldown)
  if not skip_cooldown then
    local now = os.time()
    if now - (xp_data.session.last_type_time or 0) < 1 then return end
    xp_data.session.last_type_time = now
  end
  xp_data.xp = xp_data.xp + amount
  xp_data.total_xp = xp_data.total_xp + amount
  xp_data.session.xp_this_session = xp_data.session.xp_this_session + amount
  if xp_data.xp >= xp_data.xp_to_next then
    xp_data.xp = xp_data.xp - xp_data.xp_to_next
    xp_data.level = xp_data.level + 1
    xp_data.xp_to_next = math.floor(xp_data.xp_to_next * 1.15)
    notify(string.format("LEVEL UP! You are now level %d!", xp_data.level), vim.log.levels.WARN)
    check_achievements()
  end
  vim.schedule(save_data)
end

local function update_streak()
  local today = os.date("%Y-%m-%d")
  local last = xp_data.stats.last_play_date
  if last == today then return end
  if last == "" then
    xp_data.stats.streak_days = 1
  else
    local last_time = os.time({ year = tonumber(last:sub(1,4)), month = tonumber(last:sub(6,7)), day = tonumber(last:sub(9,10)) })
    local today_time = os.time({ year = tonumber(today:sub(1,4)), month = tonumber(today:sub(6,7)), day = tonumber(today:sub(9,10)) })
    local day_diff = math.floor((today_time - last_time) / 86400)
    if day_diff == 1 then
      xp_data.stats.streak_days = xp_data.stats.streak_days + 1
      notify(string.format("%d day streak!", xp_data.stats.streak_days))
      add_xp(xp_data.stats.streak_days * 5, true)
    elseif day_diff > 1 then
      if xp_data.stats.streak_days > 1 then
        notify("Streak broken! Starting fresh.", vim.log.levels.WARN)
      end
      xp_data.stats.streak_days = 1
    end
  end
  xp_data.stats.last_play_date = today
  xp_data.stats.sessions = xp_data.stats.sessions + 1
  vim.schedule(save_data)
end

local function show_stats()
  local stats = xp_data.stats
  local session_time = math.floor((os.time() - xp_data.session.start_time) / 60)
  local unlocked = 0
  for _ in pairs(xp_data.achievements) do unlocked = unlocked + 1 end
  local lines = {
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    string.format("Level %d | XP: %d/%d", xp_data.level, xp_data.xp, xp_data.xp_to_next),
    string.format("Total XP: %d", xp_data.total_xp),
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    string.format("Files Saved: %d", stats.files_saved),
    string.format("Characters Typed: %d", stats.chars_typed),
    string.format("Current Streak: %d days", stats.streak_days),
    string.format("Total Sessions: %d", stats.sessions),
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    string.format("This Session: %d min | %d XP",
      session_time, xp_data.session.xp_this_session),
    string.format("Achievements: %d/%d", unlocked, vim.tbl_count(achievements)),
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
  }
  notify(table.concat(lines, "\n"))
end

local function show_achievements()
  local lines = {"ACHIEVEMENTS", "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"}
  for key, ach in pairs(achievements) do
    local status = xp_data.achievements[key] and "[X]" or "[ ]"
    table.insert(lines, string.format("%s %s - %s",
      status, ach.name, ach.desc))
  end

  notify(table.concat(lines, "\n"))
end

function XP.setup()
  load_data()
  update_streak()
  vim.api.nvim_create_autocmd("BufWritePost", {
    callback = function()
      vim.schedule(function()
        local now = os.time()
        if now - xp_data.session.last_save_time < 5 then return end
        xp_data.session.last_save_time = now
        xp_data.stats.files_saved = xp_data.stats.files_saved + 1
        xp_data.session.saves_this_session = xp_data.session.saves_this_session + 1
        add_xp(15, true)
        check_achievements()
      end)
    end,
  })
  local char_count = 0
  vim.api.nvim_create_autocmd("InsertCharPre", {
    callback = function()
      char_count = char_count + 1
      xp_data.stats.chars_typed = xp_data.stats.chars_typed + 1
      if char_count >= 20 then
        add_xp(5)
        char_count = 0
      end
    end,
  })
  vim.api.nvim_create_autocmd("TextChanged", {
    callback = function()
      check_achievements()
    end,
  })
  local save_group = vim.api.nvim_create_augroup("XPAutoSave", { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = save_group,
    callback = function()
      local ok, err = pcall(function()
        local f = io.open(data_file, "w")
        if f then
          f:write(vim.fn.json_encode(xp_data))
          f:close()
        end
      end)
      if not ok then
        vim.print("XP save error on exit: " .. tostring(err))
      end
    end,
  })
  vim.api.nvim_create_user_command("XPStatus", function()
    show_stats()
  end, {})
  vim.api.nvim_create_user_command("XPAchievements", function()
    show_achievements()
  end, {})
  vim.api.nvim_create_user_command("XPReset", function()
    xp_data = {
      xp = 0,
      level = 1,
      xp_to_next = 100,
      total_xp = 0,
      achievements = {},
      stats = {
        files_saved = 0,
        chars_typed = 0,
        lines_added = 0,
        sessions = 0,
        streak_days = 0,
        last_play_date = "",
      },
      session = xp_data.session,
    }
    vim.schedule(save_data)
    notify("XP System Reset!", vim.log.levels.WARN)
  end, {})
  local session_time = math.floor((os.time() - xp_data.session.start_time) / 60)
  if xp_data.stats.streak_days > 1 then
    notify(string.format("Welcome back! %d day streak", xp_data.stats.streak_days))
  else
    notify("XP module loaded. Use ':XPStatus' to check your progress.")
  end
end

return XP
