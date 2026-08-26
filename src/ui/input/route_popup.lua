local nodes = require("src.ui.schema.popup")

local intents = {}

local function _dismiss_nodes(state)
  local popup = state.ui and state.ui.popup_screen or nil
  return popup and popup.dismiss_nodes or nodes.dismiss_nodes
end

local function _popup_confirm_intent(state)
  if state.ui and state.ui.popup_active then
    return { type = "popup_confirm" }
  end
  return nil
end

function intents.build(state)
  local specs = {}
  local dismiss_nodes = _dismiss_nodes(state)
  if type(dismiss_nodes) ~= "table" then
    return specs
  end
  for _, name in ipairs(dismiss_nodes) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        return _popup_confirm_intent(state)
      end,
    }
  end
  return specs
end

return intents

--[[ mutate4lua-manifest
version=4
projectHash=01d9b26d7601bc61
scope.0.id=chunk:src/ui/input/route_popup.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=35
scope.0.semanticHash=0e22490ec3a4f61a
scope.1.id=function:_dismiss_nodes
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=8
scope.1.semanticHash=1834ae2c981101b5
scope.2.id=function:_popup_confirm_intent
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=15
scope.2.semanticHash=00183235c1c02c67
scope.3.id=function:intents.build
scope.3.kind=function
scope.3.startLine=17
scope.3.endLine=32
scope.3.semanticHash=aa15241b6a869567
scope.4.id=function:<anonymous>
scope.4.kind=function
scope.4.startLine=26
scope.4.endLine=28
scope.4.semanticHash=7bbf31ab6751de78
]]
