local logger = require("src.foundation.log")
local nodes = require("src.ui.schema.permanent")
local choice_support = require("src.ui.view.choice_support")
local runtime_state = require("src.ui.state.runtime")
local host_runtime_ports = require("src.ui.host_bridge")

local _deny_text = {
  offer_in_phases_not_allowed = "现在还不能用这张牌哦",
  effect_group_used = "骰子效果已经用过了",
  special_condition_failed = "条件不满足",
}

local intents = {}

local function _resolve_current_item_slot_choice(state)
  local current_model = runtime_state.get_ui_model(state)
  local choice = current_model and current_model.choice or nil
  if choice_support.uses_item_slots(choice) then
    return choice
  end
  choice = runtime_state.get_pending_choice(state)
  if choice_support.uses_item_slots(choice) then
    return choice
  end
  local turn_choice = state and state.game and state.game.turn and state.game.turn.pending_choice or nil
  if choice_support.uses_item_slots(turn_choice) then
    return turn_choice
  end
  return nil
end

function intents.build(state)
  local specs = {}
  local item_slots = (state.ui and state.ui.item_slots) or nodes.item_slots or {}
  local card_outlines = (state.ui and state.ui.card_outlines) or nodes.card_outlines or {}
  for index, node_name in ipairs(item_slots) do
    local action_id = "item_slot_" .. tostring(index)
    specs[#specs + 1] = {
      name = node_name,
      build_intent = function()
        local choice = _resolve_current_item_slot_choice(state)
        if not choice then
          logger.warn("item_slot click ignored:", tostring(index))
          return nil
        end
        local slot_state = choice and choice.slot_states and choice.slot_states[index]
        if slot_state and slot_state.item_id ~= nil and not slot_state.available then
          local reason = slot_state.deny_reason
          local text = (reason and _deny_text[reason]) or "现在不能用哦"
          host_runtime_ports.enqueue_tip({
            text = text,
            duration = 1.5,
            dedupe_key = "item_deny:" .. tostring(reason),
            blocks_inter_turn = false,
            source = "ui.item_deny",
          })
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
          local choice = _resolve_current_item_slot_choice(state)
          if not choice then
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
