local ui_event_intents = require("src.presentation.interaction.UIEventIntents")
local nodes = require("src.presentation.canvas.target_choice.nodes")

local intents = {}

function intents.build(state)
  local specs = {}
  for index, name in ipairs(nodes.slots) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        return ui_event_intents.choice_select_intent(state, index, "target_select")
      end,
    }
  end
  local under_index = #nodes.slots + 1
  specs[#specs + 1] = {
    name = nodes.under,
    build_intent = function()
      return ui_event_intents.choice_select_intent(state, under_index, "target_select")
    end,
  }
  return specs
end

return intents
