local runtime_ui = require("src.ui.render.runtime_ui")

local M = {}

function M.resolve(state, deps)
  if deps and deps.runtime then
    return deps.runtime
  end
  local from_state = state and state.presentation_runtime
  if from_state and from_state.runtime then
    return from_state.runtime
  end
  return runtime_ui
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=b777fdbd6586c465
scope.0.id=chunk:src/ui/render/panel_runtime.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=17
scope.0.semanticHash=41916d3600293600
scope.1.id=function:M.resolve:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=14
scope.1.semanticHash=d652d4be28841090
]]
