local ui_nodes = require("src.presentation.shared.UINodes")

local debug_intents = {}

function debug_intents.build()
  local specs = {}
  for _, name in ipairs(ui_nodes.debug.toggle_targets or {}) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        return { type = "toggle_debug" }
      end,
    }
  end
  return specs
end

return debug_intents
