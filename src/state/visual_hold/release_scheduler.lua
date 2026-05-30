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
version=2
projectHash=5ca55ea1ce935d6b
scope.0.id=chunk:src/state/visual_hold/release_scheduler.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=63
scope.0.semanticHash=54ec46a17fea22c5
scope.1.id=function:release_scheduler.ensure_buffers:13
scope.1.kind=function
scope.1.startLine=13
scope.1.endLine=15
scope.1.semanticHash=55f6df13da7602ef
scope.2.id=function:release_scheduler.reset:17
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=19
scope.2.semanticHash=671e0092fb5e740c
scope.3.id=function:release_scheduler.register:21
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=31
scope.3.semanticHash=7e8764535cc51bd1
scope.4.id=function:anonymous@34:34
scope.4.kind=function
scope.4.startLine=34
scope.4.endLine=39
scope.4.semanticHash=a91e8b9fb6e22aeb
scope.5.id=function:_sort_callbacks:33
scope.5.kind=function
scope.5.startLine=33
scope.5.endLine=40
scope.5.semanticHash=a5459c2ec1c60f1c
scope.6.id=function:anonymous@54:54
scope.6.kind=function
scope.6.startLine=54
scope.6.endLine=59
scope.6.semanticHash=f58d5af7d6013cbb
scope.7.id=function:release_scheduler.register_deferred_replay:52
scope.7.kind=function
scope.7.startLine=52
scope.7.endLine=60
scope.7.semanticHash=4d550f6a16c316ae
]]
