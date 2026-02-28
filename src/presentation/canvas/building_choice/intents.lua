local ui_event_intents = require("src.presentation.interaction.UIEventIntents")
local nodes = require("src.presentation.canvas.building_choice.nodes")

local intents = {}

function intents.build(state)
  return {
    {
      name = nodes.confirm,
      build_intent = function()
        return ui_event_intents.choice_confirm_intent(state, "building_confirm")
      end,
    },
    {
      name = nodes.cancel,
      build_intent = function()
        return ui_event_intents.choice_cancel_intent(state, "building_cancel")
      end,
    },
  }
end

return intents
