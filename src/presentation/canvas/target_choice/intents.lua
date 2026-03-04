local logger = require("src.core.Logger")
local ui_event_intents = require("src.presentation.interaction.UIEventIntents")
local nodes = require("src.presentation.canvas.target_choice.nodes")

local intents = {}

function intents.build(state)
  return {
    {
      name = nodes.confirm,
      build_intent = function()
        local runtime = state and state.target_choice_runtime or nil
        if not runtime or runtime.locked_option_id == nil then
          logger.warn("target_confirm ignored: target not locked")
          return nil
        end
        return ui_event_intents.choice_confirm_intent(state, "target_confirm")
      end,
    },
    {
      name = nodes.cancel,
      build_intent = function()
        local runtime = state and state.target_choice_runtime or nil
        if not runtime or runtime.locked_option_id == nil then
          return nil
        end
        return { type = "target_unlock" }
      end,
    },
  }
end

return intents
