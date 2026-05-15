local logger = require("src.foundation.log")
local number_utils = require("src.foundation.number")
local ui_runtime_state = require("src.ui.state.runtime")

local common = {}

function common.build_log_prefix()
  return "[Eggy]"
end

function common.log_once(state, level, key, ...)
  ui_runtime_state.log_once(state, level, key, ...)
end

local _last_status_name
local _last_status_cash

function common.log_status(view)
  assert(view ~= nil, "missing view")
  local name = view.current_player_name
  local cash = view.current_player_cash
  if name == _last_status_name and cash == _last_status_cash then
    return
  end
  _last_status_name = name
  _last_status_cash = cash
  logger.info(
    common.build_log_prefix(),
    "玩家:",
    tostring(name),
    "现金:",
    number_utils.format_integer_part(cash)
  )
end

function common.get_ui_state(state)
  return state and state.ui or nil
end

return common
