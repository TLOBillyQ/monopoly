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

local function _wall_now_hms()
  local hms = runtime_ports.wall_now_hms()
  if type(hms) == "string" and hms ~= "" then
    return hms
  end
  return nil
end

local function _os_lib()
  return _G and _G.os
end

local function _date_text_ok(ok, text)
  return ok == true and type(text) == "string"
end

local function _os_date_hms()
  local os_lib = _os_lib()
  if os_lib and type(os_lib.date) == "function" then
    local ok, text = pcall(os_lib.date, "%H:%M:%S")
    if _date_text_ok(ok, text) then
      return text
    end
  end
  return nil
end

local function _now_hms()
  return _wall_now_hms() or _os_date_hms() or ""
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
version=4
projectHash=69b376bfda1af957
scope.0.id=chunk:src/state/event_log.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=141
scope.0.semanticHash=b9b3375c2b79b884
scope.1.id=function:event_log.new
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=13
scope.1.semanticHash=981de821f476f20d
scope.2.id=function:_wall_now_hms
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=21
scope.2.semanticHash=d565c61f3878c2c6
scope.3.id=function:_os_lib
scope.3.kind=function
scope.3.startLine=23
scope.3.endLine=25
scope.3.semanticHash=ce1032f965f621d6
scope.4.id=function:_date_text_ok
scope.4.kind=function
scope.4.startLine=27
scope.4.endLine=29
scope.4.semanticHash=9b9b0d67fc913622
scope.5.id=function:_os_date_hms
scope.5.kind=function
scope.5.startLine=31
scope.5.endLine=40
scope.5.semanticHash=e9c5b99675878438
scope.6.id=function:_now_hms
scope.6.kind=function
scope.6.startLine=42
scope.6.endLine=44
scope.6.semanticHash=4fda89eb3fd05623
scope.7.id=function:_make_item
scope.7.kind=function
scope.7.startLine=46
scope.7.endLine=54
scope.7.semanticHash=93c3dbfe7fb60629
scope.8.id=function:_append_with_limit
scope.8.kind=function
scope.8.startLine=56
scope.8.endLine=61
scope.8.semanticHash=7cb62edc9310f7fe
scope.9.id=function:_direct_append
scope.9.kind=function
scope.9.startLine=63
scope.9.endLine=67
scope.9.semanticHash=32374ad81a39b6a1
scope.10.id=function:event_log.append
scope.10.kind=function
scope.10.startLine=69
scope.10.endLine=77
scope.10.semanticHash=fd5a57e446d24c24
scope.11.id=function:event_log.push_buffer
scope.11.kind=function
scope.11.startLine=79
scope.11.endLine=83
scope.11.semanticHash=aeca665b4ce40b65
scope.12.id=function:event_log.pop_buffer
scope.12.kind=function
scope.12.startLine=85
scope.12.endLine=97
scope.12.semanticHash=73058cafa29ae8d0
scope.13.id=function:event_log.flush_buffer
scope.13.kind=function
scope.13.startLine=99
scope.13.endLine=104
scope.13.semanticHash=46f8afe4af7203bb
scope.14.id=function:event_log.get_entries
scope.14.kind=function
scope.14.startLine=106
scope.14.endLine=115
scope.14.semanticHash=a1e8000d83db1154
scope.15.id=function:event_log.get_text
scope.15.kind=function
scope.15.startLine=117
scope.15.endLine=128
scope.15.semanticHash=c40f67e25f1ef694
scope.16.id=function:event_log.get_seq
scope.16.kind=function
scope.16.startLine=130
scope.16.endLine=132
scope.16.semanticHash=c0484ae42c9068b0
scope.17.id=function:event_log.clear
scope.17.kind=function
scope.17.startLine=134
scope.17.endLine=138
scope.17.semanticHash=1fa3c0620df7ea9e
]]
