local logger = require("src.foundation.log")
local ui_event_intents = require("src.ui.input.event_intents")
local runtime_state = require("src.ui.state.runtime")
local nodes = require("src.ui.schema.remote_choice")

local intents = {}

function intents.build(state)
  local specs = {}
  for index, name in ipairs(nodes.options) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        local current_model = runtime_state.get_ui_model(state)
        local choice = current_model and current_model.choice or nil
        if not choice then
          logger.warn("remote_select without choice")
          return nil
        end
        local option_id = ui_event_intents.resolve_option_id(choice, { index = index }, state)
        if not option_id then
          logger.warn("remote_select missing option:", tostring(index))
          return nil
        end
        return { type = "choice_select", choice_id = choice.id, option_id = option_id }
      end,
    }
  end
  return specs
end

return intents

--[[ mutate4lua-manifest
version=2
projectHash=fa83331c30ff791d
scope.0.id=chunk:src/ui/input/canvas_route/remote_choice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=33
scope.0.semanticHash=c59ce6a9c6b3b7ce
scope.1.id=function:anonymous@13:13
scope.1.kind=function
scope.1.startLine=13
scope.1.endLine=26
scope.1.semanticHash=2016bf52805d958f
]]
