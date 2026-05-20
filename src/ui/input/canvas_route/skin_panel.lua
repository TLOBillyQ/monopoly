local nodes = require("src.ui.schema.skin")

local intents = {}

local function _append(specs, name, action)
  if not name then
    return
  end
  specs[#specs + 1] = {
    name = name,
    build_intent = function()
      return {
        type = "skin_panel_action",
        action = action,
      }
    end,
  }
end

function intents.build()
  local specs = {}
  _append(specs, nodes.close_button, "close")
  for slot_index, name in ipairs(nodes.action_buttons) do
    _append(specs, name, { type = "equip", slot_index = slot_index })
  end
  for slot_index, name in ipairs(nodes.card_images) do
    _append(specs, name, { type = "equip", slot_index = slot_index })
  end
  return specs
end

return intents
