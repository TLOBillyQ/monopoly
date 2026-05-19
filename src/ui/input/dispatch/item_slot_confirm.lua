local number_utils = require("src.foundation.number")
local runtime_state = require("src.ui.state.runtime")
local choice_support = require("src.ui.view.choice_support")

local item_slot_confirm = {}

local function _modal_ports(state)
  local ports = state and state.gameplay_loop_ports or nil
  return ports and ports.modal or {}
end

local function _close_confirm_state(state)
  state._item_slot_confirm_active = nil
  state._item_slot_confirm_intent = nil
  local modal = _modal_ports(state)
  if type(modal.close_choice_modal) == "function" then
    modal.close_choice_modal(state)
  end
end

local function _on_slot_choice_select(state, game, intent, opts, action_port)
  local stored = state._item_slot_confirm_intent
  _close_confirm_state(state)
  if stored then action_port.dispatch_action(game, state, stored, opts) end
end

local _SLOT_CONFIRM_DISPATCH = {
  choice_select = _on_slot_choice_select,
  choice_cancel = function(state) _close_confirm_state(state) end,
}

function item_slot_confirm.dispatch(state, game, intent, opts, action_port)
  if not state._item_slot_confirm_active then return false end
  local intent_type = intent and intent.type
  local handler = _SLOT_CONFIRM_DISPATCH[intent_type]
  if not handler then return false end
  handler(state, game, intent, opts, action_port)
  return true
end

local function _resolve_slot_index(intent)
  if not intent or intent.type ~= "ui_button" then return nil end
  local id = intent.id
  if type(id) ~= "string" then return nil end
  return number_utils.to_integer(string.match(id, "^item_slot_(%d+)$"))
end

local function _find_confirmable_slot(state, index)
  local current_model = runtime_state.get_ui_model(state)
  local choice = current_model and current_model.choice or nil
  if not choice or not choice.slot_states then return nil, nil end
  local slot = choice.slot_states[index]
  if not slot or not slot.available or not slot.item_id then return nil, nil end
  return choice, slot
end

local function _resolve_slot_option(state, index)
  local choice, slot = _find_confirmable_slot(state, index)
  if not choice or not slot then return nil, nil, nil end
  local option = choice_support.resolve_option_by_id(choice, slot.item_id)
  if not option or not option.confirm_title then return nil, nil, nil end
  return choice, slot, option
end

local function _open_slot_confirm_screen(state, modal, choice, slot, option)
  modal.open_pre_confirm_screen(state, choice, slot.item_id, option.confirm_title, option.confirm_body or "")
end

function item_slot_confirm.try_enter(state, intent)
  local index = _resolve_slot_index(intent)
  if not index then return false end
  local choice, slot, option = _resolve_slot_option(state, index)
  if not choice then return false end
  state._item_slot_confirm_active = true
  state._item_slot_confirm_intent = intent
  local modal = _modal_ports(state)
  if type(modal.open_pre_confirm_screen) ~= "function" then
    state._item_slot_confirm_active = nil
    state._item_slot_confirm_intent = nil
    return false
  end
  _open_slot_confirm_screen(state, modal, choice, slot, option)
  return true
end

return item_slot_confirm
