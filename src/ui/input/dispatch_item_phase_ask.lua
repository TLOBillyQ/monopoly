local choice_support = require("src.ui.pres.choice_support")
local runtime_state = require("src.ui.runtime.state")

local item_phase_ask_flow = {}

local function _modal_ports(state)
  local ports = state and state.gameplay_loop_ports or nil
  return ports and ports.modal or {}
end

local function _current_choice(state)
  local current_model = runtime_state.get_ui_model(state)
  return current_model and current_model.choice or nil
end

local function _close_choice_modal(state)
  local modal = _modal_ports(state)
  if type(modal.close_choice_modal) == "function" then
    modal.close_choice_modal(state)
  end
end

local function _dispatch_single_pre_confirm_option(game, state, choice, intent, opts, action_port)
  if not choice_support.requires_item_slot_pre_confirm(choice) then
    return
  end
  if type(choice.options) ~= "table" or #choice.options ~= 1 then
    return
  end
  local opt = choice.options[1]
  local opt_id = type(opt) == "table" and opt.id or opt
  if opt_id == nil then
    return
  end
  action_port.dispatch_action(game, state, {
    type = "choice_select",
    choice_id = choice.id,
    option_id = opt_id,
    actor_role_id = intent.actor_role_id,
  }, opts)
end

local function _handle_choice_select(state, game, intent, opts, action_port)
  state._item_phase_ask_active = nil
  state._item_phase_confirmed = true
  state._suppress_item_slot_highlight_until_pick = nil
  local choice = _current_choice(state)
  state._skip_item_slot_highlight_replay_choice_id = choice and choice.id or nil
  if choice ~= nil then
    _dispatch_single_pre_confirm_option(game, state, choice, intent, opts, action_port)
  end
  _close_choice_modal(state)
  return true
end

local function _handle_choice_cancel(state, game, intent, opts, action_port)
  state._item_phase_ask_active = nil
  state._item_phase_confirmed = nil
  state._suppress_item_slot_highlight_until_pick = nil
  state._skip_item_slot_highlight_replay_choice_id = nil
  _close_choice_modal(state)
  local choice = _current_choice(state)
  if choice and choice.id then
    action_port.dispatch_action(game, state, {
      type = "choice_cancel",
      choice_id = choice.id,
      actor_role_id = intent.actor_role_id,
    }, opts)
  end
  return true
end

local INTENT_HANDLERS = {
  choice_select = _handle_choice_select,
  choice_cancel = _handle_choice_cancel,
}

function item_phase_ask_flow.dispatch(state, game, intent, opts, action_port)
  if state._item_phase_ask_active ~= true then
    return false
  end
  local handler = INTENT_HANDLERS[intent and intent.type]
  return handler and handler(state, game, intent, opts, action_port) or false
end

return item_phase_ask_flow
