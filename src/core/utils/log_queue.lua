local log_formatter = require("src.core.utils.log_formatter")

local log_queue = {}

local function _active_event_buffer(state)
  local stack = state.event_buffer_stack
  if type(stack) ~= "table" or #stack == 0 then
    return nil
  end
  return stack[#stack]
end

local function _should_collect_event(state)
  local provider = state.event_collection_enabled_provider
  if type(provider) ~= "function" then
    return true
  end
  local ok, enabled = pcall(provider)
  if not ok then
    return true
  end
  return enabled == true
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

local function _resolve_no_tip(level, opts)
  if level == "event" and opts and opts.no_tip == true then
    return true
  end
  return false
end

local function _try_buffer_event(state, level, text, no_tip)
  if level ~= "event" then
    return false
  end
  local active_buffer = _active_event_buffer(state)
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

local function _should_skip_event_collection(state, level)
  if level ~= "event" then
    return false
  end
  return not _should_collect_event(state)
end

local function _advance_event_seq(state, level)
  if level == "event" then
    state.event_seq = (state.event_seq or 0) + 1
  end
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
  table.insert(state.entries, entry)
  if #state.entries > state.max_entries then
    table.remove(state.entries, 1)
  end
end

local function _notify_entry_sinks(state, entry)
  if state.ui_sink then
    state.ui_sink(entry)
  end
  if type(print) == "function" then
    pcall(print, log_formatter.format_entry(entry))
  end
end

function log_queue.push(state, level, opts, ...)
  if level == "info" and _check_info_turn_limit(state, opts) then
    return
  end
  local no_tip = _resolve_no_tip(level, opts)
  local text = log_formatter.stringify(1, ...)
  if _try_buffer_event(state, level, text, no_tip) then
    return
  end
  if _should_skip_event_collection(state, level) then
    return
  end
  _advance_event_seq(state, level)
  local entry = _create_entry(state, level, text)
  _store_entry(state, entry)
  _notify_entry_sinks(state, entry)
end

function log_queue.push_event_buffer(state, buffer)
  assert(type(buffer) == "table", "missing event buffer")
  local stack = state.event_buffer_stack
  if type(stack) ~= "table" then
    stack = {}
    state.event_buffer_stack = stack
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

function log_queue.pop_event_buffer(state, buffer)
  local stack = state.event_buffer_stack
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

function log_queue.flush_event_buffer(state, buffer)
  if type(buffer) ~= "table" then
    return false
  end
  if _active_event_buffer(state) == buffer then
    log_queue.pop_event_buffer(state, buffer)
  end
  local entries = buffer.entries
  if type(entries) ~= "table" or #entries == 0 then
    return false
  end
  buffer.entries = {}
  for _, entry in ipairs(entries) do
    if entry.no_tip == true then
      log_queue.push(state, "event", { no_tip = true }, entry.text or "")
    else
      log_queue.push(state, "event", nil, entry.text or "")
    end
  end
  return true
end

return log_queue
