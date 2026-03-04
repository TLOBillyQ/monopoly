local logger = require("src.core.Logger")
local ui_event_intents = require("src.presentation.interaction.UIEventIntents")
local nodes = require("src.presentation.canvas.target_choice.nodes")

local intents = {}

function intents.build(state)
  local specs = {
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
  for index, name in ipairs(nodes.slot_buttons or {}) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        local choice = state.ui_model and state.ui_model.choice or nil
        if not choice then
          logger.warn("target_lock without choice")
          return nil
        end
        local option_id = ui_event_intents.resolve_option_id(choice, { index = index }, state)
        if not option_id then
          logger.warn("target_lock missing option:", tostring(index))
          return nil
        end
        return { type = "target_lock", option_id = option_id }
      end,
    }
  end
  return specs
end

return intents
