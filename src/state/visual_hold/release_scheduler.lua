local release_scheduler = {}
local event_log = require("src.state.event_log")

local release_priority = {
  board_visual_sync = 1,
  runtime_event = 2,
  tile_update = 3,
  owner_change = 4,
  bankruptcy_clear = 5,
  popup = 6,
}

function release_scheduler.ensure_buffers(hold)
  hold.release_callbacks = hold.release_callbacks or {}
end

function release_scheduler.reset(hold)
  hold.release_callbacks = {}
end

function release_scheduler.register(hold, key, fn, opts)
  assert(type(fn) == "function", "missing release callback")
  opts = opts or {}
  hold.release_callbacks[#hold.release_callbacks + 1] = {
    key = key,
    fn = fn,
    order = #hold.release_callbacks + 1,
    priority = release_priority[key] or opts.priority or 100,
  }
  return fn
end

local function _sort_callbacks(release_callbacks)
  table.sort(release_callbacks, function(left, right)
    if left.priority ~= right.priority then
      return left.priority < right.priority
    end
    return left.order < right.order
  end)
end

function release_scheduler.replay(hold)
  event_log.flush_buffer(hold)
  _sort_callbacks(hold.release_callbacks)
  for _, entry in ipairs(hold.release_callbacks) do
    if type(entry.fn) == "function" then
      entry.fn()
    end
  end
end

function release_scheduler.register_deferred_replay(hold, key, replay, ...)
  local replay_args = { ... }
  return release_scheduler.register(hold, key, function()
    if type(replay) == "function" then
      return replay(table.unpack(replay_args))
    end
    return nil
  end)
end

return release_scheduler

--[[ mutate4lua-manifest
version=4
projectHash=81f4bec51fd6ea8f
scope.0.id=chunk:src/state/visual_hold/release_scheduler.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=63
scope.0.semanticHash=168a1370714acc26
scope.1.id=function:release_scheduler.ensure_buffers
scope.1.kind=function
scope.1.startLine=13
scope.1.endLine=15
scope.1.semanticHash=4f3697d1740687d5
scope.2.id=function:release_scheduler.reset
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=19
scope.2.semanticHash=71cf7d660694c7cf
scope.3.id=function:release_scheduler.register
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=31
scope.3.semanticHash=ca1e70f8187655ec
scope.4.id=function:_sort_callbacks
scope.4.kind=function
scope.4.startLine=33
scope.4.endLine=40
scope.4.semanticHash=caac6ed9cbb4e386
scope.5.id=function:<anonymous>
scope.5.kind=function
scope.5.startLine=34
scope.5.endLine=39
scope.5.semanticHash=7c126760b5631241
scope.6.id=function:release_scheduler.replay
scope.6.kind=function
scope.6.startLine=42
scope.6.endLine=50
scope.6.semanticHash=b30778be11009888
scope.7.id=function:release_scheduler.register_deferred_replay
scope.7.kind=function
scope.7.startLine=52
scope.7.endLine=60
scope.7.semanticHash=12e01286ef5d14c1
scope.8.id=function:<anonymous>#2
scope.8.kind=function
scope.8.startLine=54
scope.8.endLine=59
scope.8.semanticHash=bf4265f76e6603ae
]]
