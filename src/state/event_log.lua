local runtime_ports = require("src.foundation.ports.runtime_ports")

local event_log = {}
local DEFAULT_CAPACITY = 200

function event_log.new(capacity)
  return {
    entries = {},
    capacity = capacity or DEFAULT_CAPACITY,
    seq = 0,
    active_buffers = {},
  }
end

local function _now_hms()
  local hms = runtime_ports.wall_now_hms()
  if type(hms) == "string" and hms ~= "" then
    return hms
  end
  local os_lib = _G and _G.os
  if os_lib and type(os_lib.date) == "function" then
    local ok, text = pcall(os_lib.date, "%H:%M:%S")
    if ok and type(text) == "string" then
      return text
    end
  end
  return ""
end

local function _make_item(log, entry)
  log.seq = log.seq + 1
  return {
    kind = entry.kind,
    text = entry.text,
    seq = log.seq,
    time_text = _now_hms(),
  }
end

local function _append_with_limit(log, item)
  table.insert(log.entries, item)
  while #log.entries > log.capacity do
    table.remove(log.entries, 1)
  end
end

local function _direct_append(log, entry)
  local item = _make_item(log, entry)
  _append_with_limit(log, item)
  return item
end

function event_log.append(log, entry)
  local item = _direct_append(log, entry)
  local top = log.active_buffers[#log.active_buffers]
  if top then
    top.pending = top.pending or {}
    top.pending[#top.pending + 1] = item
  end
  return item
end

function event_log.push_buffer(log, hold)
  hold.pending = hold.pending or {}
  hold._event_log_ref = log
  log.active_buffers[#log.active_buffers + 1] = hold
end

function event_log.pop_buffer(hold)
  local log = hold and hold._event_log_ref
  if not log then
    return
  end
  for i = #log.active_buffers, 1, -1 do
    if log.active_buffers[i] == hold then
      table.remove(log.active_buffers, i)
      break
    end
  end
  hold._event_log_ref = nil
end

function event_log.flush_buffer(hold)
  if hold then
    hold.pending = nil
  end
  event_log.pop_buffer(hold)
end

function event_log.get_entries(log, limit)
  local out = {}
  local n = #log.entries
  local read_limit = limit or n
  local start = math.max(1, n - read_limit + 1)
  for i = start, n do
    out[#out + 1] = log.entries[i]
  end
  return out
end

function event_log.get_text(log, limit)
  local entries = event_log.get_entries(log, limit)
  local lines = {}
  for i, e in ipairs(entries) do
    if e.time_text then
      lines[i] = e.time_text .. " " .. e.text
    else
      lines[i] = e.text
    end
  end
  return table.concat(lines, "\n")
end

function event_log.get_seq(log)
  return log.seq
end

function event_log.clear(log)
  log.entries = {}
  log.seq = 0
  log.active_buffers = {}
end

return event_log

--[[ mutate4lua-manifest
version=2
projectHash=3d9055f8b523a209
scope.0.id=chunk:src/state/event_log.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=125
scope.0.semanticHash=c1e9b24a20e3ebde
scope.1.id=function:event_log.new:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=13
scope.1.semanticHash=e67ba2707fbbc438
scope.2.id=function:_now_hms:15
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=28
scope.2.semanticHash=6b4e073e89eb4cd7
scope.3.id=function:_make_item:30
scope.3.kind=function
scope.3.startLine=30
scope.3.endLine=38
scope.3.semanticHash=0ce5658cad893a79
scope.4.id=function:_direct_append:47
scope.4.kind=function
scope.4.startLine=47
scope.4.endLine=51
scope.4.semanticHash=8f9e7c631e126e1a
scope.5.id=function:event_log.append:53
scope.5.kind=function
scope.5.startLine=53
scope.5.endLine=61
scope.5.semanticHash=102530dd5a260751
scope.6.id=function:event_log.push_buffer:63
scope.6.kind=function
scope.6.startLine=63
scope.6.endLine=67
scope.6.semanticHash=5132a52047866d49
scope.7.id=function:event_log.flush_buffer:83
scope.7.kind=function
scope.7.startLine=83
scope.7.endLine=88
scope.7.semanticHash=567d77fea6276935
scope.8.id=function:event_log.get_seq:114
scope.8.kind=function
scope.8.startLine=114
scope.8.endLine=116
scope.8.semanticHash=1651a613a78562a5
scope.9.id=function:event_log.clear:118
scope.9.kind=function
scope.9.startLine=118
scope.9.endLine=122
scope.9.semanticHash=31db19bf64df414f
]]
