local number_utils = require("src.foundation.lang.number")
local runtime_state = require("src.ui.state.runtime")
local choice_support = require("src.ui.view.choice_support")

local item_slot_confirm = {}

local function _modal_ports(state)
  local ports = state and state.gameplay_loop_ports or nil
  return ports and ports.modal or {}
end

function item_slot_confirm.dispatch(state, game, intent, opts, action_port)
  if not state._item_slot_confirm_active then
    return false
  end
  local intent_type = intent and intent.type
  if intent_type == "choice_select" then
    local stored = state._item_slot_confirm_intent
    state._item_slot_confirm_active = nil
    state._item_slot_confirm_intent = nil
    local modal = _modal_ports(state)
    if type(modal.close_choice_modal) == "function" then
      modal.close_choice_modal(state)
    end
    if stored then
      action_port.dispatch_action(game, state, stored, opts)
    end
    return true
  end
  if intent_type == "choice_cancel" then
    state._item_slot_confirm_active = nil
    state._item_slot_confirm_intent = nil
    local modal = _modal_ports(state)
    if type(modal.close_choice_modal) == "function" then
      modal.close_choice_modal(state)
    end
    return true
  end
  return false
end

function item_slot_confirm.try_enter(state, intent)
  if not intent or intent.type ~= "ui_button" then
    return false
  end
  local id = intent.id
  if type(id) ~= "string" then
    return false
  end
  local index = number_utils.to_integer(string.match(id, "^item_slot_(%d+)$"))
  if not index then
    return false
  end
  local current_model = runtime_state.get_ui_model(state)
  local choice = current_model and current_model.choice or nil
  if not choice or not choice.slot_states then
    return false
  end
  local slot = choice.slot_states[index]
  if not slot or not slot.available or not slot.item_id then
    return false
  end
  local option = choice_support.resolve_option_by_id(choice, slot.item_id)
  if not option or not option.confirm_title then
    return false
  end
  state._item_slot_confirm_active = true
  state._item_slot_confirm_intent = intent
  local modal = _modal_ports(state)
  if type(modal.open_pre_confirm_screen) ~= "function" then
    state._item_slot_confirm_active = nil
    state._item_slot_confirm_intent = nil
    return false
  end
  modal.open_pre_confirm_screen(state, choice, slot.item_id, option.confirm_title, option.confirm_body or "")
  return true
end

return item_slot_confirm
