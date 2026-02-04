local logger = {
  entries = {},
  max_entries = 200,
  seq = 0,
  timestamp_provider = function()
    return 0
  end,
  time_formatter = function(timestamp)
    return tostring(timestamp)
  end,
}

local function _stringify(...)
  local parts = {}
  for i = 1, select("#", ...) do
    parts[i] = tostring(select(i, ...))
  end
  return table.concat(parts, " ")
end

local function _get_timestamp()
  return logger.timestamp_provider()
end

local function _format_timestamp(timestamp)
  return logger.time_formatter(timestamp)
end

local function _push(level, ...)
  local text = _stringify(...)
  local timestamp = _get_timestamp()
  local time_text = _format_timestamp(timestamp)
  logger.seq = logger.seq + 1
  local entry = {
    level = level,
    text = text,
    timestamp = timestamp,
    time_text = time_text,
    seq = logger.seq,
  }
  table.insert(logger.entries, entry)
  if #logger.entries > logger.max_entries then
    table.remove(logger.entries, 1)
  end
  if logger.ui_sink then
    logger.ui_sink(entry)
  end
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

  local function _pad2(value)
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
    return tostring(year) .. "-" .. _pad2(month) .. "-" .. _pad2(day)
      .. " " .. _pad2(hour) .. ":" .. _pad2(minute) .. ":" .. _pad2(second)
  end)
end

function logger.set_file_io_enabled(enabled)
  logger.enable_file_io = enabled == true
end

function logger.set_ui_sink(sink)
  logger.ui_sink = sink
end

function logger.info(...)
  _push("info", ...)
end

function logger.warn(...)
  _push("warn", ...)
end

function logger.event(...)
  _push("event", ...)
end

function logger.clear()
  logger.entries = {}
  logger.seq = logger.seq + 1
end

function logger.get_seq()
  return logger.seq
end

local function _format_entry(entry)
  local time_text = entry.time_text or ""
  local level = entry.level or ""
  local text = entry.text or ""
  if time_text ~= "" then
    return time_text .. " [" .. level .. "] " .. text
  end
  return "[" .. level .. "] " .. text
end

function logger.get_entries(max_lines)
  local entries = logger.entries
  local total = #entries
  local want = max_lines or total
  if want > total then
    want = total
  end
  local out = {}
  for i = total - want + 1, total do
    out[#out + 1] = entries[i]
  end
  return out
end

function logger.get_text(max_lines)
  local list = logger.get_entries(max_lines)
  local lines = {}
  for _, entry in ipairs(list) do
    lines[#lines + 1] = _format_entry(entry)
  end
  return table.concat(lines, "\n")
end

return logger
