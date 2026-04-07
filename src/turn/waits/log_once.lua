local logger = require("src.core.utils.logger")
local runtime_state = require("src.state.runtime_state")

local wait_log_once = {}

local function _mark_once(state, key)
  assert(state ~= nil, "missing state")
  local debug_runtime = runtime_state.ensure_debug_runtime(state)
  assert(debug_runtime.log_once ~= nil, "missing state.debug_runtime.log_once")
  if debug_runtime.log_once[key] then
    return false
  end
  debug_runtime.log_once[key] = true
  return true
end

function wait_log_once.info(state, key, ...)
  if not _mark_once(state, key) then
    return false
  end
  logger.info(...)
  return true
end

function wait_log_once.warn(state, key, ...)
  if not _mark_once(state, key) then
    return false
  end
  logger.warn(...)
  return true
end

return wait_log_once
