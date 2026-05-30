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

--[[ mutate4lua-manifest
version=2
projectHash=4d0b157ce15834e6
scope.0.id=chunk:src/ui/ports/common.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=41
scope.0.semanticHash=cc0d32e45af96c60
scope.1.id=function:common.build_log_prefix:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=9
scope.1.semanticHash=8fd28505fe0ca49e
scope.2.id=function:common.log_once:11
scope.2.kind=function
scope.2.startLine=11
scope.2.endLine=13
scope.2.semanticHash=ad2617b31015a3ae
scope.3.id=function:common.log_status:18
scope.3.kind=function
scope.3.startLine=18
scope.3.endLine=34
scope.3.semanticHash=a2e43184d9c28a6c
scope.4.id=function:common.get_ui_state:36
scope.4.kind=function
scope.4.startLine=36
scope.4.endLine=38
scope.4.semanticHash=6776064f14307c81
]]
