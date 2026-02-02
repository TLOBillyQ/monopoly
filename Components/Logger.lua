local logger = {
  entries = {},
  max_entries = 200,
  adapter = { level = nil, on_log = function() end },
  timestamp_provider = function()
    return 0
  end,
  time_formatter = function(timestamp)
    return tostring(timestamp)
  end,
}

local function stringify(...)
  local parts = {}
  for i = 1, select("#", ...) do
    parts[i] = tostring(select(i, ...))
  end
  return table.concat(parts, " ")
end

local function get_timestamp()
  return logger.timestamp_provider()
end

local function format_timestamp(timestamp)
  return logger.time_formatter(timestamp)
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
  local allow = adapter.level
  local allow_kind = type(allow)
  local should_call = true
  if allow_kind == "table" then
    should_call = false
    for _, value in ipairs(allow) do
      if value == entry.level then
        should_call = true
        break
      end
    end
  elseif allow_kind ~= "nil" then
    should_call = allow == entry.level
  end
  if should_call then
    local ok, err = pcall(adapter.on_log, entry)
    if not ok then
      print("[logger] adapter error: " .. tostring(err))
    end
  end
end

function logger.set_adapter(adapter)
  logger.adapter = adapter or { level = nil, on_log = function() end }
end

function logger.set_timestamp_provider(provider)
  logger.timestamp_provider = provider
end

function logger.set_time_formatter(formatter)
  logger.time_formatter = formatter
end

function logger.configure_game_time()
  local game_api = GameAPI
  assert(game_api ~= nil, "missing GameAPI")
  logger.set_timestamp_provider(function()
    return game_api.get_timestamp()
  end)

  local function pad2(value)
    if value < 10 then
      return "0" .. tostring(value)
    end
    return tostring(value)
  end

  logger.set_time_formatter(function(timestamp)
    assert(timestamp ~= nil, "missing timestamp")
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
