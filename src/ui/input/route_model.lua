local runtime_state = require("src.ui.state.runtime")

local route_model = {}

local function _current_model(state)
  return runtime_state.get_ui_model(state)
end

function route_model.field(state, key)
  local current_model = _current_model(state)
  return current_model and current_model[key] or nil
end

function route_model.choice(state)
  return route_model.field(state, "choice")
end

function route_model.market(state)
  return route_model.field(state, "market")
end

return route_model

--[[ mutate4lua-manifest
version=4
projectHash=b4c5a87c4fec15fd
scope.0.id=chunk:src/ui/input/route_model.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=23
scope.0.semanticHash=0ea8f5bc868de033
scope.1.id=function:_current_model
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=7
scope.1.semanticHash=f1ce1850b7232305
scope.2.id=function:route_model.field
scope.2.kind=function
scope.2.startLine=9
scope.2.endLine=12
scope.2.semanticHash=837e31706e29c8d9
scope.3.id=function:route_model.choice
scope.3.kind=function
scope.3.startLine=14
scope.3.endLine=16
scope.3.semanticHash=a9c1c4b362850cf7
scope.4.id=function:route_model.market
scope.4.kind=function
scope.4.startLine=18
scope.4.endLine=20
scope.4.semanticHash=a9c1c4b362850cf7
]]
