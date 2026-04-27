local number_utils = require("src.core.utils.number")

local M = {}

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
    return { done = true }
  end
  local started, started_now = _resolve_seconds_wait(key, session, now)
  if started_now then
    return { wait = true }
  end
  if (now - started) < wait_sec then
    return { wait = true }
  end
  session._seconds_wait[key] = nil
  return { done = true }
end

function M.seconds(session, sec, opts)
  assert(session ~= nil, "missing await session")
  local wait_sec = sec or 0
  if wait_sec <= 0 then
    return { done = true }
  end
  return _await_seconds_step(session, wait_sec, opts)
end

return M
