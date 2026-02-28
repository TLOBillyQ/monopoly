local logger = require("src.core.Logger")
local nodes = require("src.presentation.canvas.base.nodes")

local intents = {}

function intents.build(state)
  local specs = {}
  local item_slots = (state.ui and state.ui.item_slots) or nodes.item_slots or {}
  local card_outlines = (state.ui and state.ui.card_outlines) or nodes.card_outlines or {}
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
    local outline_name = card_outlines[index]
    if outline_name then
      specs[#specs + 1] = {
        name = outline_name,
        build_intent = function()
          local choice = state.ui_model and state.ui_model.choice or nil
          if not choice or choice.kind ~= "item_phase_choice" then
            logger.warn("item_slot outline click ignored:", tostring(index))
            return nil
          end
          return { type = "ui_button", id = action_id }
        end,
      }
    end
  end
  return specs
end

return intents
