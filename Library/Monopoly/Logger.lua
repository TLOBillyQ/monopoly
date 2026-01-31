local logger = {
  entries = {},
  max_entries = 200,
  adapter = nil,
  timestamp_provider = nil,
  time_formatter = nil,
}

local function stringify(...)
  local parts = {}
  for i = 1, select("#", ...) do
    parts[i] = tostring(select(i, ...))
  end
  return table.concat(parts, " ")
end

local function get_timestamp()
  local provider = logger.timestamp_provider
  if provider then
    return provider()
  end
  return 0
end

local function format_timestamp(timestamp)
  local formatter = logger.time_formatter
  if formatter then
    return formatter(timestamp)
  end
  return tostring(timestamp or 0)
end

local function push(level, ...)
  local text = stringify(...)
  local timestamp = get_timestamp()
  local time_text = format_timestamp(timestamp)
  local entry = {
    level = level,
    text = text,
    timestamp = timestamp,
    time_text = time_text,
  }
  table.insert(logger.entries, entry)
  if #logger.entries > logger.max_entries then
    table.remove(logger.entries, 1)
  end
  local adapter = logger.adapter
  if adapter and adapter.on_log then
    local allow = adapter.level
    local should_call = false
    if allow == nil then
      should_call = true
    elseif type(allow) == "table" then
      for _, value in ipairs(allow) do
        if value == entry.level then
          should_call = true
          break
        end
      end
    else
      should_call = allow == entry.level
    end
    if should_call then
      local ok, err = pcall(adapter.on_log, entry)
      if not ok then
        print("[logger] adapter error: " .. tostring(err))
      end
    end
  end
end

function logger.set_adapter(adapter)
  logger.adapter = adapter
end

function logger.set_timestamp_provider(provider)
  logger.timestamp_provider = provider
end

function logger.set_time_formatter(formatter)
  logger.time_formatter = formatter
end

function logger.configure_game_time()
  local game_api = GameAPI
  if not game_api then
    return
  end
  if game_api.get_timestamp then
    logger.set_timestamp_provider(function()
      return game_api.get_timestamp()
    end)
  end

  local function pad2(value)
    if value < 10 then
      return "0" .. tostring(value)
    end
    return tostring(value)
  end

  logger.set_time_formatter(function(timestamp)
    if timestamp == nil then
      return "0"
    end
    local year = game_api.get_year(timestamp)
    local month = game_api.get_month(timestamp)
    local day = game_api.get_day(timestamp)
    local hour = game_api.get_hour(timestamp)
    local minute = game_api.get_minute(timestamp)
    local second = game_api.get_second(timestamp)
    return tostring(year) .. "-" .. pad2(month) .. "-" .. pad2(day)
      .. " " .. pad2(hour) .. ":" .. pad2(minute) .. ":" .. pad2(second)
  end)
end

function logger.set_file_io_enabled(enabled)
  logger.enable_file_io = enabled == true
end

function logger.info(...)
  push("info", ...)
end

function logger.warn(...)
  push("warn", ...)
end

function logger.event(...)
  push("event", ...)
end

function logger.clear()
  logger.entries = {}
end

return logger
