local ui_event_intents = require("src.ui.input.event_intents")
local nodes = require("src.ui.schema.player_choice")

local intents = {}

function intents.build(state)
  local specs = {}
  for index, name in ipairs(nodes.slots) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        return ui_event_intents.choice_select_intent(state, index, "player_select")
      end,
    }
  end
  return specs
end

return intents

--[[ mutate4lua-manifest
version=2
projectHash=f67a6254a9fcbd99
scope.0.id=chunk:src/ui/input/canvas_route/player_choice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=20
scope.0.semanticHash=006773193c5bf0ee
scope.1.id=function:anonymous@11:11
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=13
scope.1.semanticHash=152005556507b71b
]]
