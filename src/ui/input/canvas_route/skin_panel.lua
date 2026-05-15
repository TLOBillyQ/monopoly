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

local function _append_slot_actions(specs, names)
  for slot_index, name in ipairs(names or {}) do
    _append(specs, name, { type = "equip", slot_index = slot_index })
  end
end

function intents.build()
  local specs = {}
  _append(specs, nodes.close_button, "close")
  _append(specs, nodes.page_prev, "prev")
  _append(specs, nodes.page_next, "next")
  _append_slot_actions(specs, nodes.slots)
  _append_slot_actions(specs, nodes.action_buttons)
  _append_slot_actions(specs, nodes.action_labels)
  return specs
end

return intents
