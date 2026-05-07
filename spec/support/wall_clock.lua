local M = {}

local function _now_ms()
  return os.clock() * 1000.0
end

local function _traceback(err)
  if type(traceback) == "function" then
    return traceback(err)
  end
  return tostring(err)
end

function M.start()
  return {
    started_ms = _now_ms(),
    source = "os.clock",
  }
end

function M.finish(timer)
  local ended_ms = _now_ms()
  local started_ms = timer and timer.started_ms or 0
  local elapsed_ms = ended_ms - started_ms
  if elapsed_ms < 0 then
    elapsed_ms = 0
  end
  return {
    elapsed_ms = elapsed_ms,
    source = timer and timer.source or "os.clock",
  }
end

function M.measure(fn)
  local timer = M.start()
  local ok, result = xpcall(fn, _traceback)
  local timing = M.finish(timer)
  if not ok then
    error(result)
  end
  return result, timing
end

return M
