local nodes = require("src.ui.schema.popup")

local intents = {}

function intents.build(state)
  local specs = {}
  local popup = state.ui and state.ui.popup_screen or nil
  local dismiss_nodes = popup and popup.dismiss_nodes or nodes.dismiss_nodes
  if type(dismiss_nodes) ~= "table" then
    return specs
  end
  for _, name in ipairs(dismiss_nodes) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        if state.ui and state.ui.popup_active then
          return { type = "popup_confirm" }
        end
        return nil
      end,
    }
  end
  return specs
end

return intents

--[[ mutate4lua-manifest
version=2
projectHash=9f9175d1f56c95d7
scope.0.id=chunk:src/ui/input/canvas_route/popup.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=27
scope.0.semanticHash=65d286544e3d747f
scope.1.id=function:anonymous@15:15
scope.1.kind=function
scope.1.startLine=15
scope.1.endLine=20
scope.1.semanticHash=02d01545866fe963
]]
