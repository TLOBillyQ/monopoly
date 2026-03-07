local logger = require("src.core.utils.Logger")
local number_utils = require("src.core.utils.NumberUtils")
local runtime_state = require("src.core.runtime_facade.RuntimeState")

local common = {}

function common.build_log_prefix()
  return "[Eggy]"
end

function common.log_once(state, level, key, ...)
  local debug_runtime = runtime_state.ensure_debug_runtime(state)
  if debug_runtime.log_once[key] then
    return
  end
  debug_runtime.log_once[key] = true
  if level == "warn" then
    logger.warn(...)
  else
    logger.info(...)
  end
end

function common.log_status(view)
  assert(view ~= nil, "missing view")
  logger.info(
    common.build_log_prefix(),
    "玩家:",
    tostring(view.current_player_name),
    "现金:",
    number_utils.format_integer_part(view.current_player_cash)
  )
end

function common.get_ui_state(state)
  return state and state.ui or nil
end

return common
