local logger = {
  entries = {},
  max_entries = 200,
  seq = 0,
  info_per_turn_limit = nil,
  info_turn_provider = nil,
  info_turn = nil,
  info_turn_count = 0,
  timestamp_provider = function()
    return 0
  end,
  time_formatter = function(timestamp)
    return tostring(timestamp)
  end,
}

local function _stringify(start_index, ...)
  local start = start_index or 1
  local parts = {}
  local out_index = 1
  for i = start, select("#", ...) do
    parts[out_index] = tostring(select(i, ...))
    out_index = out_index + 1
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
  if level == "info" then
    local limit = logger.info_per_turn_limit
    local provider = logger.info_turn_provider
    if limit and limit > 0 and provider then
      local turn = provider()
      if turn ~= nil then
        if logger.info_turn ~= turn then
          logger.info_turn = turn
          logger.info_turn_count = 0
        end
        if logger.info_turn_count >= limit then
          return
        end
        logger.info_turn_count = logger.info_turn_count + 1
      end
    end
  end
  local no_tip = false
  local text_start = 1
  if level == "event" then
    local opts = select(1, ...)
    if type(opts) == "table" and opts.no_tip == true then
      no_tip = true
      text_start = 2
    end
  end
  local text = _stringify(text_start, ...)
  if level == "event" and not no_tip then
    local global_api = GlobalAPI
    if global_api and global_api.show_tips then
      global_api.show_tips(text, 2.0)
    end
  end
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
    local hour = game_api.get_hour(timestamp)
    local minute = game_api.get_minute(timestamp)
    local second = game_api.get_second(timestamp)
    return _pad2(hour) .. ":" .. _pad2(minute) .. ":" .. _pad2(second)
  end)
end

function logger.set_file_io_enabled(enabled)
  logger.enable_file_io = enabled == true
end

function logger.set_info_per_turn_limit(limit)
  logger.info_per_turn_limit = limit
end

function logger.set_info_turn_provider(provider)
  logger.info_turn_provider = provider
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

function logger.error(...)
  _push("error", ...)
end

function logger.event(...)
  _push("event", ...)
end

function logger.event_no_tips(...)
  _push("event", { no_tip = true }, ...)
end

function logger.clear()
  logger.entries = {}
  logger.seq = logger.seq + 1
  logger.info_turn = nil
  logger.info_turn_count = 0
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
