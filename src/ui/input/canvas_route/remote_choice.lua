local logger = require("src.core.utils.logger")
local ui_event_intents = require("src.ui.input.event_intents")
local runtime_state = require("src.ui.state")
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
