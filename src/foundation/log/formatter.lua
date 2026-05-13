local log_formatter = {}

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

local function _notify_entry_sinks(state, entry)
  if state.ui_sink then
    state.ui_sink(entry)
  end
  if type(print) == "function" then
    pcall(print, log_formatter.format_entry(entry))
  end
end

function log_formatter.push(state, level, opts, ...)
  if level == "info" and _check_info_turn_limit(state, opts) then
    return
  end
  local text = log_formatter.stringify(1, ...)
  local entry = _create_entry(state, level, text)
  _store_entry(state, entry)
  _notify_entry_sinks(state, entry)
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

local _stringify_parts = {}

function log_formatter.stringify(start_index, ...)
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

function log_formatter.format_entry(entry)
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

function log_formatter.get_entries(state, max_lines)
  return _take_entries(_list_entries(state), max_lines)
end

function log_formatter.get_entries_by_level(state, level, max_lines)
  if level == nil then
    return log_formatter.get_entries(state, max_lines)
  end
  local matched = {}
  local entries = _list_entries(state)
  for _, entry in ipairs(entries) do
    if entry.level == level then
      matched[#matched + 1] = entry
    end
  end
  return _take_entries(matched, max_lines)
end

local function _entries_to_text(entries)
  local lines = {}
  for _, entry in ipairs(entries) do
    lines[#lines + 1] = log_formatter.format_entry(entry)
  end
  return table.concat(lines, "\n")
end

function log_formatter.get_text(state, max_lines)
  return _entries_to_text(log_formatter.get_entries(state, max_lines))
end

function log_formatter.get_text_by_level(state, level, max_lines)
  return _entries_to_text(log_formatter.get_entries_by_level(state, level, max_lines))
end

return log_formatter
