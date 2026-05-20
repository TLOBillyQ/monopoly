local nodes = require("src.ui.schema.item_atlas")

local intents = {}

local function _append(specs, name, action)
  if not name then
    return
  end
  specs[#specs + 1] = {
    name = name,
    build_intent = function()
      return {
        type = "item_atlas_action",
        action = action,
      }
    end,
  }
end

function intents.build()
  local specs = {}
  _append(specs, nodes.close_button, "close")
  _append(specs, nodes.close_blank, "dismiss")
  _append(specs, nodes.page_prev, "prev")
  _append(specs, nodes.page_next, "next")
  for slot_index, name in ipairs(nodes.card_images) do
    _append(specs, name, { type = "select", slot_index = slot_index })
  end
  return specs
end

return intents
