local logger = require("src.foundation.log")
local ui_event_intents = require("src.ui.input.event_intents")
local nodes = require("src.ui.schema.target_choice")
local runtime_state = require("src.ui.state.runtime")

local intents = {}

function intents.build(state)
  local specs = {
    {
      name = nodes.confirm,
      build_intent = function()
        return nil
      end,
    },
    {
      name = nodes.cancel,
      build_intent = function()
        return nil
      end,
    },
  }
  for index, name in ipairs(nodes.slot_buttons or {}) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        local current_model = runtime_state.get_ui_model(state)
        local choice = current_model and current_model.choice or nil
        if not choice then
          logger.warn("target_select without choice")
          return nil
        end
        local options = choice.options
        local resolve_index = (type(options) == "table" and #options == 1) and 1 or index
        local option_id = ui_event_intents.resolve_option_id(choice, { index = resolve_index }, state)
        if not option_id then
          logger.warn("target_select missing option:", tostring(resolve_index))
          return nil
        end
        return {
          type = "choice_select",
          choice_id = choice.id,
          option_id = option_id,
        }
      end,
    }
  end
  return specs
end

return intents

--[[ mutate4lua-manifest
version=2
projectHash=74a7b1e6f0197fb0
scope.0.id=chunk:src/ui/input/canvas_route/target_choice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=52
scope.0.semanticHash=73687ed913c35224
scope.1.id=function:anonymous@12:12
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=14
scope.1.semanticHash=d8269153568043a6
scope.2.id=function:anonymous@18:18
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=20
scope.2.semanticHash=d8269153568043a6
scope.3.id=function:anonymous@26:26
scope.3.kind=function
scope.3.startLine=26
scope.3.endLine=45
scope.3.semanticHash=a32bc031257f4e43
]]
