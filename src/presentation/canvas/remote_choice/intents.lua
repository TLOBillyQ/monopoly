local logger = require("src.core.Logger")
local ui_event_intents = require("src.presentation.interaction.UIEventIntents")
local nodes = require("src.presentation.canvas.remote_choice.nodes")

local intents = {}

function intents.build(state)
  local specs = {}
  for index, name in ipairs(nodes.options) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        local choice = state.ui_model and state.ui_model.choice or nil
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
  specs[#specs + 1] = {
    name = nodes.cancel,
    build_intent = function()
      return ui_event_intents.choice_cancel_intent(state, "remote_cancel")
    end,
  }
  return specs
end

return intents
