local logger = require("src.foundation.log.logger")
local runtime_state = require("src.state.runtime_state")

local logger_utils = {}

function logger_utils.log_once(state, level, key, ...)
  local debug_runtime = runtime_state.ensure_debug_runtime(state)
  if debug_runtime.log_once[key] then
    return false
  end
  debug_runtime.log_once[key] = true
  if level == "warn" then
    logger.warn(...)
  else
    logger.info(...)
  end
  return true
end

return logger_utils
