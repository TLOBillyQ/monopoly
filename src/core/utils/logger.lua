local logger = {
  entries = {},
  max_entries = 200,
  seq = 0,
  event_seq = 0,
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
  event_buffer_stack = {},
  event_collection_enabled_provider = nil,
  anim_debug_enabled_provider = nil,
  test_mode = false,
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

local _format_entry

local function _active_event_buffer()
  local stack = logger.event_buffer_stack
  if type(stack) ~= "table" or #stack == 0 then
    return nil
  end
  return stack[#stack]
end

local function _should_collect_event()
  local provider = logger.event_collection_enabled_provider
  if type(provider) ~= "function" then
    return true
  end
  local ok, enabled = pcall(provider)
  if not ok then
    return true
  end
  return enabled == true
end

local function _check_info_turn_limit(opts)
  if opts and opts.unlimited == true then
    return false
  end
  local limit = logger.info_per_turn_limit
  local provider = logger.info_turn_provider
  if not (limit and limit > 0 and provider) then
    return false
  end
  local turn = provider()
  if turn == nil then
    return false
  end
  if logger.info_turn ~= turn then
    logger.info_turn = turn
    logger.info_turn_count = 0
  end
  if logger.info_turn_count >= limit then
    return true
  end
  logger.info_turn_count = logger.info_turn_count + 1
  return false
end

local function _resolve_no_tip(level, opts)
  if level == "event" and opts and opts.no_tip == true then
    return true
  end
  return false
end

local function _try_buffer_event(level, text, no_tip)
  if level ~= "event" then
    return false
  end
  local active_buffer = _active_event_buffer()
  if type(active_buffer) ~= "table" then
    return false
  end
  local entries = active_buffer.entries
  if type(entries) ~= "table" then
    entries = {}
    active_buffer.entries = entries
  end
  entries[#entries + 1] = {
    level = level,
    text = text,
    no_tip = no_tip,
  }
  return true
end

local function _should_skip_event_collection(level)
  if level ~= "event" then
    return false
  end
  return not _should_collect_event()
end

local function _advance_event_seq(level)
  if level == "event" then
    logger.event_seq = (logger.event_seq or 0) + 1
  end
end

local function _create_entry(level, text)
  local timestamp = _get_timestamp()
  local time_text = _format_timestamp(timestamp)
  logger.seq = logger.seq + 1
  return {
    level = level,
    text = text,
    timestamp = timestamp,
    time_text = time_text,
    seq = logger.seq,
  }
end

local function _store_entry(entry)
  table.insert(logger.entries, entry)
  if #logger.entries > logger.max_entries then
    table.remove(logger.entries, 1)
  end
end

local function _notify_entry_sinks(entry)
  if logger.ui_sink then
    logger.ui_sink(entry)
  end
  if type(print) == "function" then
    pcall(print, _format_entry(entry))
  end
end

local function _push(level, opts, ...)
  if level == "info" and _check_info_turn_limit(opts) then
    return
  end
  local no_tip = _resolve_no_tip(level, opts)
  local text = _stringify(1, ...)
  if _try_buffer_event(level, text, no_tip) then
    return
  end
  if _should_skip_event_collection(level) then
    return
  end
  _advance_event_seq(level)
  local entry = _create_entry(level, text)
  _store_entry(entry)
  _notify_entry_sinks(entry)
end

function logger.set_timestamp_provider(provider)
  logger.timestamp_provider = provider
end

function logger.set_time_formatter(formatter)
  logger.time_formatter = formatter
end

function logger.reset_time_runtime()
  logger.set_timestamp_provider(function()
    return 0
  end)
  logger.set_time_formatter(function(timestamp)
    return tostring(timestamp)
  end)
end

function logger.set_event_collection_enabled_provider(provider)
  if provider ~= nil then
    assert(type(provider) == "function", "event collection provider must be function or nil")
  end
  logger.event_collection_enabled_provider = provider
end

function logger.set_anim_debug_enabled_provider(provider)
  if provider ~= nil then
    assert(type(provider) == "function", "anim debug provider must be function or nil")
  end
  logger.anim_debug_enabled_provider = provider
end

function logger.set_test_mode(enabled)
  logger.test_mode = enabled == true
end

function logger.is_test_mode()
  return logger.test_mode == true
end

function logger.is_anim_debug_enabled()
  local provider = logger.anim_debug_enabled_provider
  if type(provider) ~= "function" then
    return false
  end
  local ok, enabled = pcall(provider)
  if not ok then
    return false
  end
  return enabled == true
end

function logger.configure_game_time(game_api)
  assert(game_api ~= nil, "missing game api")
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
  _push("info", nil, ...)
end

function logger.info_unlimited(...)
  _push("info", { unlimited = true }, ...)
end

function logger.warn(...)
  _push("warn", nil, ...)
end

function logger.event(...)
  _push("event", nil, ...)
end

function logger.event_no_tips(...)
  _push("event", { no_tip = true }, ...)
end

function logger.clear()
  logger.entries = {}
  logger.seq = logger.seq + 1
  logger.event_seq = (logger.event_seq or 0) + 1
  logger.info_turn = nil
  logger.info_turn_count = 0
  logger.event_buffer_stack = {}
end

function logger.get_seq()
  return logger.seq
end

function logger.get_event_seq()
  return logger.event_seq or 0
end

function _format_entry(entry)
  local time_text = entry.time_text or ""
  local level = entry.level or ""
  local text = entry.text or ""
  if time_text ~= "" then
    return time_text .. " [" .. level .. "] " .. text
  end
  return "[" .. level .. "] " .. text
end

local function _take_entries(entries, max_lines)
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

function logger.get_entries(max_lines)
  return _take_entries(logger.entries, max_lines)
end

function logger.get_entries_by_level(level, max_lines)
  if level == nil then
    return logger.get_entries(max_lines)
  end
  local matched = {}
  for _, entry in ipairs(logger.entries) do
    if entry.level == level then
      matched[#matched + 1] = entry
    end
  end
  return _take_entries(matched, max_lines)
end

function logger.get_text(max_lines)
  local list = logger.get_entries(max_lines)
  local lines = {}
  for _, entry in ipairs(list) do
    lines[#lines + 1] = _format_entry(entry)
  end
  return table.concat(lines, "\n")
end

function logger.get_text_by_level(level, max_lines)
  local list = logger.get_entries_by_level(level, max_lines)
  local lines = {}
  for _, entry in ipairs(list) do
    lines[#lines + 1] = _format_entry(entry)
  end
  return table.concat(lines, "\n")
end

function logger.push_event_buffer(buffer)
  assert(type(buffer) == "table", "missing event buffer")
  local stack = logger.event_buffer_stack
  if type(stack) ~= "table" then
    stack = {}
    logger.event_buffer_stack = stack
  end
  for _, current in ipairs(stack) do
    if current == buffer then
      return buffer
    end
  end
  if type(buffer.entries) ~= "table" then
    buffer.entries = {}
  end
  stack[#stack + 1] = buffer
  return buffer
end

function logger.pop_event_buffer(buffer)
  local stack = logger.event_buffer_stack
  if type(stack) ~= "table" or #stack == 0 then
    return nil
  end
  if buffer == nil then
    return table.remove(stack)
  end
  for index = #stack, 1, -1 do
    if stack[index] == buffer then
      return table.remove(stack, index)
    end
  end
  return nil
end

function logger.flush_event_buffer(buffer)
  if type(buffer) ~= "table" then
    return false
  end
  if _active_event_buffer() == buffer then
    logger.pop_event_buffer(buffer)
  end
  local entries = buffer.entries
  if type(entries) ~= "table" or #entries == 0 then
    return false
  end
  buffer.entries = {}
  for _, entry in ipairs(entries) do
    if entry.no_tip == true then
      _push("event", { no_tip = true }, entry.text or "")
    else
      _push("event", nil, entry.text or "")
    end
  end
  return true
end

return logger
