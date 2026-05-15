local tip_queue = require("src.foundation.tips")

local _stringify_parts = {}

local function _stringify(start_index, ...)
  local start = start_index or 1
  local out_index = 1
  for i = start, select("#", ...) do
    _stringify_parts[out_index] = tostring(select(i, ...))
    out_index = out_index + 1
  end
  for i = out_index, #_stringify_parts do
    _stringify_parts[i] = nil
  end
  return table.concat(_stringify_parts, " ")
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

local function _check_info_turn_limit(state, opts)
  if opts and opts.unlimited == true then
    return false
  end
  local limit = state.info_per_turn_limit
  local provider = state.info_turn_provider
  if not (limit and limit > 0 and provider) then
    return false
  end
  local turn = provider()
  if turn == nil then
    return false
  end
  if state.info_turn ~= turn then
    state.info_turn = turn
    state.info_turn_count = 0
  end
  if state.info_turn_count >= limit then
    return true
  end
  state.info_turn_count = state.info_turn_count + 1
  return false
end

local function _create_entry(state, level, text)
  local timestamp = state.timestamp_provider()
  local time_text = state.time_formatter(timestamp)
  state.seq = state.seq + 1
  return {
    level = level,
    text = text,
    timestamp = timestamp,
    time_text = time_text,
    seq = state.seq,
  }
end

local function _store_entry(state, entry)
  local entries = state.entries
  if type(entries) ~= "table" then
    entries = {}
    state.entries = entries
  end

  local max_entries = state.max_entries
  local head = state.entries_head or 1
  local count = state.entries_count

  if count == nil or (#entries == 0 and count > 0) then
    count = #entries
    head = 1
  end

  if max_entries <= 0 then
    return
  end

  if count < max_entries then
    local tail_index = ((head + count - 1) % max_entries) + 1
    entries[tail_index] = entry
    state.entries_count = count + 1
    state.entries_head = head
    return
  end

  entries[head] = entry
  state.entries_head = (head % max_entries) + 1
  state.entries_count = max_entries
end

local function _list_entries(state)
  local entries = state.entries or {}
  local count = state.entries_count
  local head = state.entries_head

  if count == nil or head == nil then
    return entries
  end

  if count <= 0 or #entries == 0 then
    return {}
  end

  local capacity = state.max_entries or #entries
  if capacity <= 0 then
    return {}
  end

  local out = {}
  for i = 1, count do
    local slot = ((head + i - 2) % capacity) + 1
    out[#out + 1] = entries[slot]
  end
  return out
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

local function _entries_to_text(entries)
  local lines = {}
  for _, entry in ipairs(entries) do
    lines[#lines + 1] = _format_entry(entry)
  end
  return table.concat(lines, "\n")
end

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
  anim_debug_enabled_provider = nil,
  test_mode = false,
  enabled = true,
}

function logger.set_enabled(b)
  logger.enabled = b and true or false
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

function logger.set_anim_debug_enabled_provider(provider)
  if provider ~= nil then
    assert(type(provider) == "function", "anim debug provider must be function or nil")
  end
  logger.anim_debug_enabled_provider = provider
end

function logger.set_test_mode(enabled)
  logger.test_mode = enabled == true
  tip_queue.configure_runtime({
    test_mode = logger.test_mode,
  })
end

function logger.is_test_mode()
  return logger.test_mode == true
end

function logger.is_anim_debug_enabled()
  local provider = logger.anim_debug_enabled_provider
  if type(provider) ~= "function" then
    return false
  end
  local ok, result = pcall(provider)
  if not ok then
    return false
  end
  return result == true
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

function logger.set_info_per_turn_limit(limit)
  logger.info_per_turn_limit = limit
end

function logger.set_info_turn_provider(provider)
  logger.info_turn_provider = provider
end

function logger.set_ui_sink(sink)
  logger.ui_sink = sink
end

local function _push(state, level, opts, ...)
  if level == "info" and _check_info_turn_limit(state, opts) then
    return
  end
  local text = _stringify(1, ...)
  local entry = _create_entry(state, level, text)
  _store_entry(state, entry)
  if state.ui_sink then
    state.ui_sink(entry)
  end
  if type(print) == "function" then
    pcall(print, _format_entry(entry))
  end
end

function logger.info(...)
  if not logger.enabled then
    return
  end
  _push(logger, "info", nil, ...)
end

local _info_unlimited_opts = { unlimited = true }

function logger.info_unlimited(...)
  if not logger.enabled then
    return
  end
  _push(logger, "info", _info_unlimited_opts, ...)
end

function logger.warn(...)
  if not logger.enabled then
    return
  end
  _push(logger, "warn", nil, ...)
end

function logger.clear()
  logger.entries = {}
  logger.seq = logger.seq + 1
  logger.event_seq = (logger.event_seq or 0) + 1
  logger.info_turn = nil
  logger.info_turn_count = 0
end

function logger.get_seq()
  return logger.seq
end

function logger.get_entries(max_lines)
  return _take_entries(_list_entries(logger), max_lines)
end

function logger.get_entries_by_level(level, max_lines)
  if level == nil then
    return logger.get_entries(max_lines)
  end
  local matched = {}
  local entries = _list_entries(logger)
  for _, entry in ipairs(entries) do
    if entry.level == level then
      matched[#matched + 1] = entry
    end
  end
  return _take_entries(matched, max_lines)
end

function logger.get_text(max_lines)
  return _entries_to_text(logger.get_entries(max_lines))
end

function logger.get_text_by_level(level, max_lines)
  return _entries_to_text(logger.get_entries_by_level(level, max_lines))
end

function logger.log_once(sink, level, key, ...)
  assert(type(sink) == "table", "missing dedupe sink")
  if sink[key] then
    return false
  end
  sink[key] = true
  if level == "warn" then
    logger.warn(...)
  else
    logger.info(...)
  end
  return true
end

logger.stringify = _stringify
logger.format_entry = _format_entry
logger.formatter = {
  stringify = _stringify,
  format_entry = _format_entry,
  push = _push,
  get_entries = function(state, max_lines)
    return _take_entries(_list_entries(state), max_lines)
  end,
  get_entries_by_level = function(state, level, max_lines)
    if level == nil then
      return _take_entries(_list_entries(state), max_lines)
    end
    local matched = {}
    for _, entry in ipairs(_list_entries(state)) do
      if entry.level == level then
        matched[#matched + 1] = entry
      end
    end
    return _take_entries(matched, max_lines)
  end,
  get_text = function(state, max_lines)
    return _entries_to_text(_take_entries(_list_entries(state), max_lines))
  end,
  get_text_by_level = function(state, level, max_lines)
    if level == nil then
      return _entries_to_text(_take_entries(_list_entries(state), max_lines))
    end
    local matched = {}
    for _, entry in ipairs(_list_entries(state)) do
      if entry.level == level then
        matched[#matched + 1] = entry
      end
    end
    return _entries_to_text(_take_entries(matched, max_lines))
  end,
}

return logger
