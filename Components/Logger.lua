local logger = {
  entries = {},
  max_entries = 200,
  timestamp_provider = function()
    return 0
  end,
  time_formatter = function(timestamp)
    return tostring(timestamp)
  end,
}

local function _Stringify(...)
  local parts = {}
  for i = 1, select("#", ...) do
    parts[i] = tostring(select(i, ...))
  end
  return table.concat(parts, " ")
end

local function _GetTimestamp()
  return logger.timestamp_provider()
end

local function _FormatTimestamp(timestamp)
  return logger.time_formatter(timestamp)
end

local function _Push(level, ...)
  local text = _Stringify(...)
  local timestamp = _GetTimestamp()
  local time_text = _FormatTimestamp(timestamp)
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
end

function logger.SetTimestampProvider(provider)
  logger.timestamp_provider = provider
end

function logger.SetTimeFormatter(formatter)
  logger.time_formatter = formatter
end

function logger.ConfigureGameTime()
  local game_api = GameAPI
  assert(game_api ~= nil, "missing GameAPI")
  logger.SetTimestampProvider(function()
    return game_api.get_timestamp()
  end)

  local function _Pad2(value)
    if value < 10 then
      return "0" .. tostring(value)
    end
    return tostring(value)
  end

  logger.SetTimeFormatter(function(timestamp)
    assert(timestamp ~= nil, "missing timestamp")
    local year = game_api.get_year(timestamp)
    local month = game_api.get_month(timestamp)
    local day = game_api.get_day(timestamp)
    local hour = game_api.get_hour(timestamp)
    local minute = game_api.get_minute(timestamp)
    local second = game_api.get_second(timestamp)
    return tostring(year) .. "-" .. _Pad2(month) .. "-" .. _Pad2(day)
      .. " " .. _Pad2(hour) .. ":" .. _Pad2(minute) .. ":" .. _Pad2(second)
  end)
end

function logger.SetFileIoEnabled(enabled)
  logger.enable_file_io = enabled == true
end

function logger.Info(...)
  _Push("info", ...)
end

function logger.Warn(...)
  _Push("warn", ...)
end

function logger.Event(...)
  _Push("event", ...)
end

function logger.Clear()
  logger.entries = {}
end

return logger
