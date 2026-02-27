local nodes = require("src.presentation.canvas.always_show.nodes")

local intents = {}

function intents.build()
  return {
    {
      name = nodes.action_log_button,
      build_intent = function()
        return { type = "toggle_action_log" }
      end,
    },
  }
end

return intents
