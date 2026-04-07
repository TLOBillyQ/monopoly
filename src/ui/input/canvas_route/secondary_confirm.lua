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
