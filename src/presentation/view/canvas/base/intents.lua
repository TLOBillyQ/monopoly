local base_nodes = require("src.presentation.view.canvas.base.nodes")

local intents = {}

function intents.build(state)
  return {
    {
      name = base_nodes.action_button,
      build_intent = function()
        return { type = "ui_button", id = "next" }
      end,
    },
  }
end

return intents
