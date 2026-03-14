local nodes = require("src.ui.schema.canvas.popup.nodes")

local intents = {}

function intents.build(state)
  local specs = {}
  local popup = state.ui and state.ui.popup_screen or nil
  local dismiss_nodes = popup and popup.dismiss_nodes or nodes.dismiss_nodes
  if type(dismiss_nodes) ~= "table" then
    return specs
  end
  for _, name in ipairs(dismiss_nodes) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        if state.ui and state.ui.popup_active then
          return { type = "popup_confirm" }
        end
        return nil
      end,
    }
  end
  return specs
end

return intents
