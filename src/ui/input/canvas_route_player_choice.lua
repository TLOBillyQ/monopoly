local ui_event_intents = require("src.ui.input.event_intents")
local nodes = require("src.ui.schema.player_choice_nodes")

local intents = {}

function intents.build(state)
  local specs = {}
  for index, name in ipairs(nodes.slots) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        return ui_event_intents.choice_select_intent(state, index, "player_select")
      end,
    }
  end
  return specs
end

return intents
