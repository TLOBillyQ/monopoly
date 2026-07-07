local number_utils = require("src.foundation.number")
local shared = require("src.turn.waits.await_shared")

local _WAIT = shared.WAIT
local _DONE = shared.DONE

local function _resolve_seconds_wait(key, session, now)
  local started = session._seconds_wait[key]
  if started == nil then
    session._seconds_wait[key] = now
    return nil, true
  end
  return started, false
end

local function _resolve_seconds_now(now_fn)
  if type(now_fn) ~= "function" then
    return nil
  end
  local ok, now_or_err = pcall(now_fn)
  if not ok or not number_utils.is_numeric(now_or_err) then
    return nil
  end
  return now_or_err
end

local function _resolve_seconds_key(opts)
  if type(opts) ~= "table" or opts.key == nil then
    return "__default__"
  end
  return opts.key
end

local function _await_seconds_step(session, wait_sec, opts)
  local key = _resolve_seconds_key(opts)
  local now = _resolve_seconds_now(opts and opts.now_fn)
  if now == nil then
    return _DONE
  end
  local started, started_now = _resolve_seconds_wait(key, session, now)
  if started_now then
    return _WAIT
  end
  if (now - started) < wait_sec then
    return _WAIT
  end
  session._seconds_wait[key] = nil
  return _DONE
end

local function _seconds(session, sec, opts)
  assert(session ~= nil, "missing await session")
  local wait_sec = sec or 0
  if wait_sec <= 0 then
    return _DONE
  end
  return _await_seconds_step(session, wait_sec, opts)
end

local seconds = {}

seconds.seconds = _seconds

return seconds

--[[ mutate4lua-manifest
version=2
projectHash=016f05e27ba908cc
scope.0.id=chunk:src/turn/waits/await_seconds.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=65
scope.0.semanticHash=ff35e69fedfe980f
scope.0.lastMutatedAt=2026-07-07T02:12:21Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=2
scope.0.lastMutationKilled=2
scope.1.id=function:_resolve_seconds_wait:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=14
scope.1.semanticHash=d78bb7367d63ec99
scope.1.lastMutatedAt=2026-07-07T02:12:21Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=3
scope.1.lastMutationKilled=3
scope.2.id=function:_resolve_seconds_now:16
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=25
scope.2.semanticHash=540a3c244aefb314
scope.2.lastMutatedAt=2026-07-07T02:12:21Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=8
scope.2.lastMutationKilled=8
scope.3.id=function:_resolve_seconds_key:27
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=32
scope.3.semanticHash=7eb2f4bb67e93ccc
scope.3.lastMutatedAt=2026-07-07T02:12:21Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=6
scope.3.lastMutationKilled=6
scope.4.id=function:_await_seconds_step:34
scope.4.kind=function
scope.4.startLine=34
scope.4.endLine=49
scope.4.semanticHash=cb99b31c3eabbb0f
scope.4.lastMutatedAt=2026-07-07T02:12:21Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=6
scope.4.lastMutationKilled=6
scope.5.id=function:_seconds:51
scope.5.kind=function
scope.5.startLine=51
scope.5.endLine=58
scope.5.semanticHash=dce1f2278566bd2e
scope.5.lastMutatedAt=2026-07-07T02:12:21Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=survived
scope.5.lastMutationSites=6
scope.5.lastMutationKilled=4
]]
