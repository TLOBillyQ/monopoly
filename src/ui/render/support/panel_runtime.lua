local runtime_ui = require("src.ui.render.support.runtime_ui")

local M = {}

local function _runtime_from_state(state)
  local from_state = state and state.presentation_runtime
  if from_state and from_state.runtime then
    return from_state.runtime
  end
  return nil
end

function M.resolve(state, deps)
  if deps and deps.runtime then
    return deps.runtime
  end
  return _runtime_from_state(state) or runtime_ui
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=79018701416f05b5
scope.0.id=chunk:src/ui/render/support/panel_runtime.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=21
scope.0.semanticHash=d7b25fdce14434c0
scope.1.id=function:_runtime_from_state
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=11
scope.1.semanticHash=98ad05d367addf8f
scope.2.id=function:M.resolve
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=18
scope.2.semanticHash=934561898c826d68
]]
