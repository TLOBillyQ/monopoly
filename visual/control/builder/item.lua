local logger = require("core.logger")

local item_slot_intents = {}

function item_slot_intents.build(state)
  local specs = {}
  local item_slots = (state.ui and state.ui.item_slots) or {}
  if #item_slots == 0 then
    item_slots = { "道具槽位1", "道具槽位2", "道具槽位3", "道具槽位4", "道具槽位5" }
  end
  for index, node_name in ipairs(item_slots) do
    local action_id = "item_slot_" .. tostring(index)
    specs[#specs + 1] = {
      name = node_name,
      build_intent = function()
        local choice = state.ui_model and state.ui_model.choice or nil
        if not choice or choice.kind ~= "item_phase_choice" then
          logger.warn("item_slot click ignored:", tostring(index))
          return nil
        end
        return { type = "ui_button", id = action_id }
      end,
    }
  end
  return specs
end

return item_slot_intents
