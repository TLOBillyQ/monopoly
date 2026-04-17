local log_formatter = {}

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

function log_formatter.stringify(start_index, ...)
  local start = start_index or 1
  local parts = {}
  local out_index = 1
  for i = start, select("#", ...) do
    parts[out_index] = tostring(select(i, ...))
    out_index = out_index + 1
  end
  return table.concat(parts, " ")
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

function log_formatter.get_text(state, max_lines)
  local list = log_formatter.get_entries(state, max_lines)
  local lines = {}
  for _, entry in ipairs(list) do
    lines[#lines + 1] = log_formatter.format_entry(entry)
  end
  return table.concat(lines, "\n")
end

function log_formatter.get_text_by_level(state, level, max_lines)
  local list = log_formatter.get_entries_by_level(state, level, max_lines)
  local lines = {}
  for _, entry in ipairs(list) do
    lines[#lines + 1] = log_formatter.format_entry(entry)
  end
  return table.concat(lines, "\n")
end

return log_formatter
