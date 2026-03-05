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
  tip_queue = {},
  tip_active = false,
  tip_epoch = 0,
  tip_trace_enabled = true,
}
local number_utils = require("src.core.NumberUtils")

local TIP_TRACE_MAX_PREVIEW_LEN = 160

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

local function _tip_trace_preview(value)
  local ok, text = pcall(tostring, value)
  if not ok then
    return "<tostring_failed>"
  end
  if text == nil then
    return "<nil>"
  end
  if #text > TIP_TRACE_MAX_PREVIEW_LEN then
    return string.sub(text, 1, TIP_TRACE_MAX_PREVIEW_LEN) .. "..."
  end
  return text
end

local function _tip_trace_vector_hint(value)
  if type(value) ~= "table" then
    return nil
  end
  local x = value.x or value[1]
  local y = value.y or value[2]
  local z = value.z or value[3]
  if x == nil and y == nil and z == nil then
    return nil
  end
  return "x=" .. _tip_trace_preview(x) .. ",y=" .. _tip_trace_preview(y) .. ",z=" .. _tip_trace_preview(z)
end

local function _looks_like_vector_text(text)
  if type(text) ~= "string" then
    return false
  end
  if string.find(text, "Vector3", 1, true) ~= nil then
    return true
  end
  if string.find(text, "x=", 1, true) and string.find(text, "y=", 1, true) and string.find(text, "z=", 1, true) then
    return true
  end
  local x, y, z = string.match(text, "^%s*[%(%[]?%s*(-?%d+%.?%d*)%s*,%s*(-?%d+%.?%d*)%s*,%s*(-?%d+%.?%d*)%s*[%)%]]?%s*$")
  return x ~= nil and y ~= nil and z ~= nil
end

local function _tip_trace_origin()
  if not (debug and type(debug.getinfo) == "function") then
    return "debug_unavailable"
  end
  for level = 3, 16 do
    local info = debug.getinfo(level, "nSl")
    if not info then
      break
    end
    local src = info.short_src or info.source or ""
    local in_logger = string.find(src, "src/core/Logger.lua", 1, true) ~= nil
    local in_host_runtime = string.find(src, "src/presentation/api/HostRuntimePort.lua", 1, true) ~= nil
    if src ~= "" and src ~= "=[C]" and not in_logger and not in_host_runtime then
      local line = info.currentline or 0
      local fn_name = info.name or "anonymous"
      return tostring(src) .. ":" .. tostring(line) .. ":" .. tostring(fn_name)
    end
  end
  return "origin_unresolved"
end

local function _trace_tip_enqueue(raw_text, duration, queue_len, source, tip_id)
  local text_type = type(raw_text)
  local vector_hint = _tip_trace_vector_hint(raw_text)
  local preview = _tip_trace_preview(raw_text)
  local should_trace = text_type ~= "string"
    or logger.tip_trace_enabled == true
    or _looks_like_vector_text(preview)
  if not should_trace then
    return
  end
  local parts = {
    "[TipTrace][Enqueue]",
    "id=" .. tostring(tip_id),
    "source=" .. tostring(source or "unknown"),
    "text_type=" .. tostring(text_type),
    "duration=" .. tostring(duration),
    "queue_len=" .. tostring(queue_len),
    "origin=" .. _tip_trace_origin(),
    "preview=" .. preview,
  }
  if vector_hint ~= nil then
    parts[#parts + 1] = "vector_hint=" .. vector_hint
  end
  local line = table.concat(parts, " ")
  if type(print) == "function" then
    pcall(print, line)
  end
end

local function _trace_tip_dispatch(tip, duration)
  if type(tip) ~= "table" then
    return
  end
  local preview = _tip_trace_preview(tip.text)
  local should_trace = logger.tip_trace_enabled == true or _looks_like_vector_text(preview)
  if not should_trace then
    return
  end
  local line = table.concat({
    "[TipTrace][Dispatch]",
    "id=" .. tostring(tip.tip_id),
    "source=" .. tostring(tip.source or "unknown"),
    "duration=" .. tostring(duration),
    "preview=" .. preview,
  }, " ")
  if type(print) == "function" then
    pcall(print, line)
  end
end

local function _schedule_tip_release(delay, fn)
  if type(fn) ~= "function" then
    return false
  end
  if type(SetTimeOut) == "function" then
    local invoked = false
    local function _wrapped()
      invoked = true
      fn()
    end
    local ok, handled = pcall(SetTimeOut, delay, _wrapped)
    if ok and (invoked or handled == true) then
      return true
    end
    if ok and package and package.loaded and package.loaded["TestSupport"] then
      fn()
      return true
    end
    return ok
  end
  fn()
  return true
end

local function _normalize_tip_duration(duration, fallback_seconds)
  local fallback = fallback_seconds
  if not number_utils.is_numeric(fallback) or fallback <= 0 then
    fallback = 2.0
  end
  if number_utils.is_numeric(duration) and duration > 0 then
    return duration
  end
  return fallback
end

local function _tip_queue_ref()
  if type(logger.tip_queue) ~= "table" then
    logger.tip_queue = {}
  end
  return logger.tip_queue
end

local function _show_tip_immediately(text, duration)
  local global_api = GlobalAPI
  if global_api and type(global_api.show_tips) == "function" then
    local ok = pcall(global_api.show_tips, text, duration)
    return ok
  end
  return false
end

local function _dispatch_next_tip()
  if logger.tip_active then
    return
  end
  local queue = _tip_queue_ref()
  if #queue <= 0 then
    return
  end

  local tip = table.remove(queue, 1)
  if type(tip) ~= "table" then
    _dispatch_next_tip()
    return
  end

  logger.tip_active = true
  local current_epoch = logger.tip_epoch
  local duration = _normalize_tip_duration(tip.duration, 2.0)
  _trace_tip_dispatch(tip, duration)
  _show_tip_immediately(tip.text, duration)

  local function _release()
    if logger.tip_epoch ~= current_epoch then
      return
    end
    logger.tip_active = false
    _dispatch_next_tip()
  end

  local ok = _schedule_tip_release(duration, _release)
  if not ok then
    _release()
  end
end

function logger.show_tip(text, duration, meta)
  if text == nil then
    return false
  end
  local source = type(meta) == "table" and meta.source or nil
  local queue = _tip_queue_ref()
  local tip_id = (logger.tip_seq or 0) + 1
  logger.tip_seq = tip_id
  local normalized_duration = _normalize_tip_duration(duration, 2.0)
  queue[#queue + 1] = {
    text = tostring(text),
    duration = normalized_duration,
    source = source,
    raw_text = text,
    tip_id = tip_id,
  }
  _trace_tip_enqueue(text, normalized_duration, #queue, source, tip_id)
  _dispatch_next_tip()
  return true
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
    logger.show_tip(text, 2.0, { source = "logger.event" })
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
  if type(print) == "function" then
    local ok = pcall(print, _format_entry(entry))
    if not ok then
      -- ignore print failures in sandbox/runtime
    end
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
  logger.tip_queue = {}
  logger.tip_active = false
  logger.tip_epoch = (logger.tip_epoch or 0) + 1
  logger.tip_seq = 0
end

function logger.get_seq()
  return logger.seq
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

return logger
