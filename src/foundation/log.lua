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

local function _filter_entries_by_level(entries, level)
  if level == nil then
    return entries
  end
  local matched = {}
  for _, entry in ipairs(entries) do
    if entry.level == level then
      matched[#matched + 1] = entry
    end
  end
  return matched
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

local function _set_timestamp_provider(provider)
  logger.timestamp_provider = provider
end

local function _set_time_formatter(formatter)
  logger.time_formatter = formatter
end

function logger.reset_time_runtime()
  _set_timestamp_provider(function()
    return 0
  end)
  _set_time_formatter(function(timestamp)
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
  _set_timestamp_provider(function()
    return game_api.get_timestamp()
  end)

  local function _pad2(value)
    if value < 10 then
      return "0" .. tostring(value)
    end
    return tostring(value)
  end

  _set_time_formatter(function(timestamp)
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

local function _level_logger(level)
  return function(...)
    if not logger.enabled then
      return
    end
    _push(logger, level, nil, ...)
  end
end

logger.info = _level_logger("info")
logger.warn = _level_logger("warn")

local _info_unlimited_opts = { unlimited = true }

function logger.info_unlimited(...)
  if not logger.enabled then
    return
  end
  _push(logger, "info", _info_unlimited_opts, ...)
end

function logger.clear()
  logger.entries = {}
  logger.seq = logger.seq + 1
  logger.event_seq = (logger.event_seq or 0) + 1
  logger.info_turn = nil
  logger.info_turn_count = 0
end

local function _get_entries(max_lines)
  return _take_entries(_list_entries(logger), max_lines)
end

function logger.get_text(max_lines)
  return _entries_to_text(_get_entries(max_lines))
end

function logger.get_text_by_level(level, max_lines)
  return _entries_to_text(_take_entries(_filter_entries_by_level(_list_entries(logger), level), max_lines))
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
    return _take_entries(_filter_entries_by_level(_list_entries(state), level), max_lines)
  end,
  get_text = function(state, max_lines)
    return _entries_to_text(_take_entries(_list_entries(state), max_lines))
  end,
  get_text_by_level = function(state, level, max_lines)
    return _entries_to_text(_take_entries(_filter_entries_by_level(_list_entries(state), level), max_lines))
  end,
}

return logger

--[[ mutate4lua-manifest
version=2
projectHash=351175aa480e0a66
scope.0.id=chunk:src/foundation/log.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=354
scope.0.semanticHash=01b0a319b241cf44
scope.0.lastMutatedAt=2026-07-07T04:13:05Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=survived
scope.0.lastMutationSites=53
scope.0.lastMutationKilled=51
scope.1.id=function:_format_entry:18
scope.1.kind=function
scope.1.startLine=18
scope.1.endLine=26
scope.1.semanticHash=6f459319953b0a65
scope.1.lastMutatedAt=2026-07-07T04:13:05Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=12
scope.1.lastMutationKilled=12
scope.2.id=function:_check_info_turn_limit:28
scope.2.kind=function
scope.2.startLine=28
scope.2.endLine=50
scope.2.semanticHash=0e41c7f1d438e7df
scope.2.lastMutatedAt=2026-07-07T04:13:05Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=20
scope.2.lastMutationKilled=20
scope.3.id=function:_create_entry:52
scope.3.kind=function
scope.3.startLine=52
scope.3.endLine=63
scope.3.semanticHash=e888cc09d8e14fcb
scope.3.lastMutatedAt=2026-07-07T04:13:05Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=4
scope.3.lastMutationKilled=4
scope.4.id=function:_store_entry:65
scope.4.kind=function
scope.4.startLine=65
scope.4.endLine=96
scope.4.semanticHash=a871a51a252b3a43
scope.4.lastMutatedAt=2026-07-07T04:13:05Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=25
scope.4.lastMutationKilled=25
scope.5.id=function:anonymous@167:167
scope.5.kind=function
scope.5.startLine=167
scope.5.endLine=169
scope.5.semanticHash=f25f2cab992f7889
scope.5.lastMutatedAt=2026-07-07T04:13:05Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=1
scope.5.lastMutationKilled=1
scope.6.id=function:anonymous@170:170
scope.6.kind=function
scope.6.startLine=170
scope.6.endLine=172
scope.6.semanticHash=d9111bfa15cdd12e
scope.6.lastMutatedAt=2026-07-07T04:13:05Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=1
scope.6.lastMutationKilled=1
scope.7.id=function:logger.set_enabled:178
scope.7.kind=function
scope.7.startLine=178
scope.7.endLine=180
scope.7.semanticHash=62ba0806f124da52
scope.7.lastMutatedAt=2026-07-07T04:13:05Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=4
scope.7.lastMutationKilled=4
scope.8.id=function:_set_timestamp_provider:182
scope.8.kind=function
scope.8.startLine=182
scope.8.endLine=184
scope.8.semanticHash=c448b12a5b962bc8
scope.9.id=function:_set_time_formatter:186
scope.9.kind=function
scope.9.startLine=186
scope.9.endLine=188
scope.9.semanticHash=af20c4073f9db252
scope.10.id=function:anonymous@191:191
scope.10.kind=function
scope.10.startLine=191
scope.10.endLine=193
scope.10.semanticHash=f25f2cab992f7889
scope.11.id=function:anonymous@194:194
scope.11.kind=function
scope.11.startLine=194
scope.11.endLine=196
scope.11.semanticHash=d9111bfa15cdd12e
scope.12.id=function:logger.reset_time_runtime:190
scope.12.kind=function
scope.12.startLine=190
scope.12.endLine=197
scope.12.semanticHash=acedb9a368ddc3d4
scope.12.lastMutatedAt=2026-07-07T04:13:05Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=2
scope.12.lastMutationKilled=2
scope.13.id=function:logger.set_anim_debug_enabled_provider:199
scope.13.kind=function
scope.13.startLine=199
scope.13.endLine=204
scope.13.semanticHash=77c61d9434ce143f
scope.13.lastMutatedAt=2026-07-07T04:13:05Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=2
scope.13.lastMutationKilled=2
scope.14.id=function:logger.set_test_mode:206
scope.14.kind=function
scope.14.startLine=206
scope.14.endLine=211
scope.14.semanticHash=7e4e6fd132b74937
scope.14.lastMutatedAt=2026-07-07T04:13:05Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=3
scope.14.lastMutationKilled=3
scope.15.id=function:logger.is_test_mode:213
scope.15.kind=function
scope.15.startLine=213
scope.15.endLine=215
scope.15.semanticHash=6b82188bbe338650
scope.15.lastMutatedAt=2026-07-07T04:13:05Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=passed
scope.15.lastMutationSites=2
scope.15.lastMutationKilled=2
scope.16.id=function:logger.is_anim_debug_enabled:217
scope.16.kind=function
scope.16.startLine=217
scope.16.endLine=227
scope.16.semanticHash=e1c89b7c683a11ed
scope.16.lastMutatedAt=2026-07-07T04:13:05Z
scope.16.lastMutationLane=behavior
scope.16.lastMutationStatus=passed
scope.16.lastMutationSites=9
scope.16.lastMutationKilled=9
scope.17.id=function:anonymous@231:231
scope.17.kind=function
scope.17.startLine=231
scope.17.endLine=233
scope.17.semanticHash=e797e8b4f7f3d016
scope.18.id=function:_pad2:235
scope.18.kind=function
scope.18.startLine=235
scope.18.endLine=240
scope.18.semanticHash=c0b540de273139a1
scope.18.lastMutatedAt=2026-07-07T04:13:05Z
scope.18.lastMutationLane=behavior
scope.18.lastMutationStatus=passed
scope.18.lastMutationSites=4
scope.18.lastMutationKilled=4
scope.19.id=function:anonymous@242:242
scope.19.kind=function
scope.19.startLine=242
scope.19.endLine=248
scope.19.semanticHash=12638332c5d82028
scope.20.id=function:logger.configure_game_time:229
scope.20.kind=function
scope.20.startLine=229
scope.20.endLine=249
scope.20.semanticHash=0cba229f8ed9b6fe
scope.20.lastMutatedAt=2026-07-07T04:13:05Z
scope.20.lastMutationLane=behavior
scope.20.lastMutationStatus=passed
scope.20.lastMutationSites=3
scope.20.lastMutationKilled=3
scope.21.id=function:logger.set_info_per_turn_limit:251
scope.21.kind=function
scope.21.startLine=251
scope.21.endLine=253
scope.21.semanticHash=87501c6bea3b5685
scope.22.id=function:logger.set_info_turn_provider:255
scope.22.kind=function
scope.22.startLine=255
scope.22.endLine=257
scope.22.semanticHash=e070b63abea32837
scope.23.id=function:logger.set_ui_sink:259
scope.23.kind=function
scope.23.startLine=259
scope.23.endLine=261
scope.23.semanticHash=9cbdcd66e01be3cb
scope.24.id=function:_push:263
scope.24.kind=function
scope.24.startLine=263
scope.24.endLine=276
scope.24.semanticHash=51c6d6c11d228673
scope.24.lastMutatedAt=2026-07-07T04:13:05Z
scope.24.lastMutationLane=behavior
scope.24.lastMutationStatus=passed
scope.24.lastMutationSites=12
scope.24.lastMutationKilled=12
scope.25.id=function:anonymous@279:279
scope.25.kind=function
scope.25.startLine=279
scope.25.endLine=284
scope.25.semanticHash=3d9020960c303347
scope.25.lastMutatedAt=2026-07-07T04:13:05Z
scope.25.lastMutationLane=behavior
scope.25.lastMutationStatus=passed
scope.25.lastMutationSites=2
scope.25.lastMutationKilled=2
scope.26.id=function:_level_logger:278
scope.26.kind=function
scope.26.startLine=278
scope.26.endLine=285
scope.26.semanticHash=0af68a571a8ba071
scope.27.id=function:logger.info_unlimited:292
scope.27.kind=function
scope.27.startLine=292
scope.27.endLine=297
scope.27.semanticHash=428b12064c58e0f4
scope.27.lastMutatedAt=2026-07-07T04:13:05Z
scope.27.lastMutationLane=behavior
scope.27.lastMutationStatus=passed
scope.27.lastMutationSites=2
scope.27.lastMutationKilled=2
scope.28.id=function:logger.clear:299
scope.28.kind=function
scope.28.startLine=299
scope.28.endLine=305
scope.28.semanticHash=32917477a52f42a4
scope.28.lastMutatedAt=2026-07-07T04:13:05Z
scope.28.lastMutationLane=behavior
scope.28.lastMutationStatus=passed
scope.28.lastMutationSites=7
scope.28.lastMutationKilled=7
scope.29.id=function:_get_entries:307
scope.29.kind=function
scope.29.startLine=307
scope.29.endLine=309
scope.29.semanticHash=746474c14dd37116
scope.29.lastMutatedAt=2026-07-07T04:13:05Z
scope.29.lastMutationLane=behavior
scope.29.lastMutationStatus=passed
scope.29.lastMutationSites=1
scope.29.lastMutationKilled=1
scope.30.id=function:logger.get_text:311
scope.30.kind=function
scope.30.startLine=311
scope.30.endLine=313
scope.30.semanticHash=4b8209dbfcc38ba6
scope.30.lastMutatedAt=2026-07-07T04:13:05Z
scope.30.lastMutationLane=behavior
scope.30.lastMutationStatus=passed
scope.30.lastMutationSites=1
scope.30.lastMutationKilled=1
scope.31.id=function:logger.get_text_by_level:315
scope.31.kind=function
scope.31.startLine=315
scope.31.endLine=317
scope.31.semanticHash=97f38d785f16a1db
scope.31.lastMutatedAt=2026-07-07T04:13:05Z
scope.31.lastMutationLane=behavior
scope.31.lastMutationStatus=passed
scope.31.lastMutationSites=1
scope.31.lastMutationKilled=1
scope.32.id=function:logger.log_once:319
scope.32.kind=function
scope.32.startLine=319
scope.32.endLine=331
scope.32.semanticHash=abf3a6f9b47fdc6f
scope.32.lastMutatedAt=2026-07-07T04:13:05Z
scope.32.lastMutationLane=behavior
scope.32.lastMutationStatus=passed
scope.32.lastMutationSites=8
scope.32.lastMutationKilled=8
scope.33.id=function:anonymous@339:339
scope.33.kind=function
scope.33.startLine=339
scope.33.endLine=341
scope.33.semanticHash=8b463e6bb71cafa4
scope.33.lastMutatedAt=2026-07-07T04:13:05Z
scope.33.lastMutationLane=behavior
scope.33.lastMutationStatus=passed
scope.33.lastMutationSites=1
scope.33.lastMutationKilled=1
scope.34.id=function:anonymous@342:342
scope.34.kind=function
scope.34.startLine=342
scope.34.endLine=344
scope.34.semanticHash=22e3638eff371086
scope.34.lastMutatedAt=2026-07-07T04:13:05Z
scope.34.lastMutationLane=behavior
scope.34.lastMutationStatus=passed
scope.34.lastMutationSites=1
scope.34.lastMutationKilled=1
scope.35.id=function:anonymous@345:345
scope.35.kind=function
scope.35.startLine=345
scope.35.endLine=347
scope.35.semanticHash=d263a679b2d557e0
scope.35.lastMutatedAt=2026-07-07T04:13:05Z
scope.35.lastMutationLane=behavior
scope.35.lastMutationStatus=passed
scope.35.lastMutationSites=1
scope.35.lastMutationKilled=1
scope.36.id=function:anonymous@348:348
scope.36.kind=function
scope.36.startLine=348
scope.36.endLine=350
scope.36.semanticHash=544ad864c9ec4d28
scope.36.lastMutatedAt=2026-07-07T04:13:05Z
scope.36.lastMutationLane=behavior
scope.36.lastMutationStatus=passed
scope.36.lastMutationSites=1
scope.36.lastMutationKilled=1
]]
