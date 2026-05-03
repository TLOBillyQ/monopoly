local logger = require("src.foundation.log.logger")
local number_utils = require("src.foundation.lang.number")
local ui_runtime_state = require("src.ui.state.runtime")

local common = {}

function common.build_log_prefix()
  return "[Eggy]"
end

function common.log_once(state, level, key, ...)
  ui_runtime_state.log_once(state, level, key, ...)
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
