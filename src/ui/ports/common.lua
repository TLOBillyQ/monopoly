local ui_runtime_state = require("src.ui.state.runtime")

local common = {}

function common.build_log_prefix()
  return "[Eggy]"
end

function common.log_once(state, level, key, ...)
  ui_runtime_state.log_once(state, level, key, ...)
end

function common.get_ui_state(state)
  return state and state.ui or nil
end

return common

--[[ mutate4lua-manifest
version=4
projectHash=6349c0f4edf068e5
scope.0.id=chunk:src/ui/ports/common.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=18
scope.0.semanticHash=147e42506c979469
scope.1.id=function:common.build_log_prefix
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=7
scope.1.semanticHash=b379cf11cedc33ad
scope.2.id=function:common.log_once
scope.2.kind=function
scope.2.startLine=9
scope.2.endLine=11
scope.2.semanticHash=f1cb5a6158da950e
scope.3.id=function:common.get_ui_state
scope.3.kind=function
scope.3.startLine=13
scope.3.endLine=15
scope.3.semanticHash=616a2ca60599c94f
]]
