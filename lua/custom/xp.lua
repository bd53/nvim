local XP = {}

local data_file = vim.fn.stdpath("config") .. "/data.json"

local ACHIEVEMENTS = {
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

local function create_default_data()
  return {
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
      start_time = os.time(),
      xp_this_session = 0,
      saves_this_session = 0,
      last_save_time = 0,
      last_type_time = 0,
    }
  }
end

local xp_data = create_default_data()
local save_timer = nil

local function load_data()
  local file = io.open(data_file, "r")
  if not file then return end
  local content = file:read("*a")
  file:close()
  local ok, decoded = pcall(vim.fn.json_decode, content)
  if ok and decoded then
    xp_data = vim.tbl_deep_extend("force", xp_data, decoded)
  end
  xp_data.session = create_default_data().session
end

local function save_data()
  if save_timer then
    save_timer:stop()
    save_timer:close()
    save_timer = nil
  end
  save_timer = vim.loop.new_timer()
  save_timer:start(100, 0, vim.schedule_wrap(function()
    local ok, err = pcall(function()
      local file = io.open(data_file, "w")
      if not file then return end
      file:write(vim.fn.json_encode(xp_data))
      file:close()
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

local function save_data_sync()
  local ok, err = pcall(function()
    local file = io.open(data_file, "w")
    if file then
      file:write(vim.fn.json_encode(xp_data))
      file:close()
    end
  end)
  if not ok then
    vim.print("XP save error on exit: " .. tostring(err))
  end
end

local function notify(msg, level)
  local has_notify, notify_plugin = pcall(require, "notify")
  if has_notify then
    notify_plugin(msg, level or vim.log.levels.INFO, { title = "XP System", timeout = 3000 })
  else
    vim.notify(msg, level or vim.log.levels.INFO)
  end
end

local function unlock_achievement(key)
  if xp_data.achievements[key] then return false end
  local achievement = ACHIEVEMENTS[key]
  if not achievement then return false end
  xp_data.achievements[key] = true
  local msg = string.format("ACHIEVEMENT UNLOCKED\n%s\n%s", achievement.name, achievement.desc)
  notify(msg, vim.log.levels.WARN)
  add_xp(50, true)
  vim.schedule(save_data)
  return true
end

local function check_achievements()
  local stats = xp_data.stats
  local level = xp_data.level
  local session_time = os.time() - xp_data.session.start_time
  if stats.files_saved >= 1 then unlock_achievement("first_save") end
  if stats.files_saved >= 10 then unlock_achievement("save_10") end
  if stats.files_saved >= 100 then unlock_achievement("save_100") end
  if level >= 5 then unlock_achievement("level_5") end
  if level >= 10 then unlock_achievement("level_10") end
  if level >= 25 then unlock_achievement("level_25") end
  if level >= 50 then unlock_achievement("level_50") end
  if stats.chars_typed >= 1000 then unlock_achievement("chars_1000") end
  if stats.chars_typed >= 10000 then unlock_achievement("chars_10000") end
  if stats.streak_days >= 7 then unlock_achievement("streak_7") end
  if stats.streak_days >= 30 then unlock_achievement("streak_30") end
  if session_time >= 1800 then unlock_achievement("session_30min") end
  if session_time >= 7200 then unlock_achievement("session_2hr") end
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
    notify(string.format("LEVEL UP. You are now level %d.", xp_data.level), vim.log.levels.WARN)
    check_achievements()
  end
  vim.schedule(save_data)
end

local function parse_date(date_str)
  return os.time({ year = tonumber(date_str:sub(1, 4)), month = tonumber(date_str:sub(6, 7)), day = tonumber(date_str:sub(9, 10))})
end

local function update_streak()
  local today = os.date("%Y-%m-%d")
  local last = xp_data.stats.last_play_date
  if last == today then return end
  if last == "" then
    xp_data.stats.streak_days = 1
  else
    local last_time = parse_date(last)
    local today_time = parse_date(today)
    local day_diff = math.floor((today_time - last_time) / 86400)
    if day_diff == 1 then
      xp_data.stats.streak_days = xp_data.stats.streak_days + 1
      notify(string.format("%d day streak.", xp_data.stats.streak_days))
      add_xp(xp_data.stats.streak_days * 5, true)
    elseif day_diff > 1 then
      if xp_data.stats.streak_days > 1 then
        notify("Streak broken. Starting fresh.", vim.log.levels.WARN)
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
  local unlocked_count = vim.tbl_count(xp_data.achievements)
  local total_achievements = vim.tbl_count(ACHIEVEMENTS)
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
    string.format("This Session: %d min | %d XP", session_time, xp_data.session.xp_this_session),
    string.format("Achievements: %d/%d", unlocked_count, total_achievements),
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
  }
  notify(table.concat(lines, "\n"))
end

local function show_achievements()
  local lines = { "ACHIEVEMENTS", "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" }
  for key, achievement in pairs(ACHIEVEMENTS) do
    local status = xp_data.achievements[key] and "[X]" or "[ ]"
    table.insert(lines, string.format("%s %s - %s", status, achievement.name, achievement.desc))
  end
  notify(table.concat(lines, "\n"))
end

local function on_file_save()
  vim.schedule(function()
    local now = os.time()
    if now - xp_data.session.last_save_time < 5 then return end
    xp_data.session.last_save_time = now
    xp_data.stats.files_saved = xp_data.stats.files_saved + 1
    xp_data.session.saves_this_session = xp_data.session.saves_this_session + 1
    add_xp(15, true)
    check_achievements()
  end)
end

local function setup_autocommands()
  vim.api.nvim_create_autocmd("BufWritePost", { callback = on_file_save })
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
  vim.api.nvim_create_autocmd("TextChanged", { callback = check_achievements })
  local save_group = vim.api.nvim_create_augroup("XPAutoSave", { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", { group = save_group, callback = save_data_sync })
end

local function setup_commands()
  vim.api.nvim_create_user_command("XPStatus", show_stats, {})
  vim.api.nvim_create_user_command("XPAchievements", show_achievements, {})
  vim.api.nvim_create_user_command("XPReset", function()
    local default = create_default_data()
    default.session = xp_data.session
    xp_data = default
    vim.schedule(save_data)
    notify("XP System Reset.", vim.log.levels.WARN)
  end, {})
end

function XP.setup()
  load_data()
  update_streak()
  setup_autocommands()
  setup_commands()
  if xp_data.stats.streak_days > 1 then
    notify(string.format("Welcome back. %d day streak.", xp_data.stats.streak_days))
  else
    notify("XP module loaded. Use ':XPStatus' to check your progress.")
  end
end

return XP
