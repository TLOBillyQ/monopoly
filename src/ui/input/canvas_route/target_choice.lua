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
