local ui_nodes = require("src.presentation.shared.UINodes")

local action_log_intents = {}

function action_log_intents.build()
  local specs = {}
  for _, name in ipairs(ui_nodes.action_log.toggle_targets or {}) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        return { type = "toggle_action_log" }
      end,
    }
  end
  return specs
end

return action_log_intents
