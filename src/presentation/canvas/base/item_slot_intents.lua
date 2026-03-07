local logger = require("src.core.utils.Logger")
local nodes = require("src.presentation.canvas.base.nodes")
local choice_common = require("src.presentation.widgets.choice_screen_service.common")
local runtime_state = require("src.core.runtime_facade.RuntimeState")

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
        local current_model = runtime_state.get_ui_model(state)
        local choice = current_model and current_model.choice or nil
        if not choice_common.uses_item_slots(choice) then
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
          local current_model = runtime_state.get_ui_model(state)
        local choice = current_model and current_model.choice or nil
          if not choice_common.uses_item_slots(choice) then
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
