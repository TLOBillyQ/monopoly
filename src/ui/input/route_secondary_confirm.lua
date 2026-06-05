local ui_event_intents = require("src.ui.input.event_intents")
local nodes = require("src.ui.schema.secondary_confirm")

local intents = {}

function intents.build(state)
  return {
    {
      name = nodes.confirm,
      build_intent = function()
        return ui_event_intents.choice_confirm_intent(state, "secondary_confirm")
      end,
    },
    {
      name = nodes.cancel,
      build_intent = function()
        return ui_event_intents.choice_cancel_intent(state, "secondary_cancel")
      end,
    },
  }
end

return intents

--[[ mutate4lua-manifest
version=2
projectHash=f7d1fb9a21e98bd8
scope.0.id=chunk:src/ui/input/route_secondary_confirm.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=24
scope.0.semanticHash=98933fd3c4348ccf
scope.1.id=function:anonymous@10:10
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=12
scope.1.semanticHash=fbdafa83f729bd04
scope.2.id=function:anonymous@16:16
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=18
scope.2.semanticHash=f6213a5f6e87b8c2
scope.3.id=function:intents.build:6
scope.3.kind=function
scope.3.startLine=6
scope.3.endLine=21
scope.3.semanticHash=75fae35409d68e75
]]
