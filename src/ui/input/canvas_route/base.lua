local base_nodes = require("src.ui.schema.base")
local event_intents = require("src.ui.input.event_intents")
local runtime_state = require("src.ui.state.runtime")

local intents = {}

function intents.build(state)
  return {
    {
      name = base_nodes.action_button,
      build_intent = function()
        local current_model = runtime_state.get_ui_model(state)
        local choice = current_model and current_model.choice or nil
        if choice and choice.kind == "item_phase_passive" then
          return event_intents.choice_cancel_intent(state, "action_button_passive")
        end
        return { type = "ui_button", id = "next" }
      end,
    },
    {
      name = base_nodes.auto_button,
      build_intent = function()
        return { type = "ui_button", id = "auto" }
      end,
    },
    {
      name = base_nodes.action_log_button,
      build_intent = function()
        return { type = "toggle_action_log" }
      end,
    },
  }
end

return intents
