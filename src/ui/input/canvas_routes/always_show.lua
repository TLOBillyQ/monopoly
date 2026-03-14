local nodes = require("src.ui.schema.canvas.always_show.nodes")

local intents = {}

function intents.build()
  return {
    {
      name = nodes.auto_button,
      build_intent = function()
        return { type = "ui_button", id = "auto" }
      end,
    },
    {
      name = nodes.action_log_button,
      build_intent = function()
        return { type = "toggle_action_log" }
      end,
    },
  }
end

return intents
