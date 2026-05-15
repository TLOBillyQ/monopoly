local choice_support = require("src.ui.view.choice_support")
local choice_contract = require("src.config.choice.contract")
local role_id_utils = require("src.foundation.identity")
local runtime_state = require("src.ui.state.runtime")

local pre_confirm_flow = {}

local function _modal_ports(state)
  local ports = state and state.gameplay_loop_ports or nil
  return ports and ports.modal or {}
end



local function _resolve_choice_owner_role_id(state, choice)
  local owner_role_id = choice_contract.resolve_owner_or_meta_role_id(choice)
  if owner_role_id ~= nil then
    return owner_role_id
  end
  local current_model = runtime_state.get_ui_model(state)
  return role_id_utils.normalize(current_model and current_model.current_player_id or nil)
end

local function _can_local_owner_open_pre_confirm(state, choice)
  local owner_role_id = _resolve_choice_owner_role_id(state, choice)
  local local_role_id = role_id_utils.normalize(runtime_state.get_local_actor_role_id(state))
  if owner_role_id == nil or local_role_id == nil then
    return false
  end
  return role_id_utils.equals(local_role_id, owner_role_id)
end

local function _requires_choice_select_pre_confirm(choice, screen_key)
  if screen_key == nil or screen_key == "secondary_confirm" or screen_key == "market" or screen_key == "target" then
    return false
  end
  if choice and choice.pre_confirm_on_select == false then
    return false
  end
  return true
end

function pre_confirm_flow.needs_pre_confirm(state, intent)
  local intent_type = intent.type
  local ui = state.ui
  local current_model = runtime_state.get_ui_model(state)
  local choice = current_model and current_model.choice or nil
  if not ui then
    return false
  end

  if intent_type == "choice_select" then
    local screen_key = ui.active_choice_screen_key
    return _requires_choice_select_pre_confirm(choice, screen_key)
  end

  return false
end

local function _resolve_enter_params(state, intent, choice)
  local source_screen = state.ui and state.ui.active_choice_screen_key or nil
  local option_id, option_label

  if intent.type == "choice_select" then
    option_id = intent.option_id
    option_label = choice_support.resolve_option_label_by_id(choice, option_id) or tostring(option_id)
  end

  if not option_id then
    return nil
  end
  local title = choice_support.resolve_secondary_confirm_title(choice, state.game, source_screen, option_id)
  local body = choice_support.resolve_secondary_confirm_body(choice, state.game, source_screen, option_id, option_label)
  return { source_screen = source_screen, option_id = option_id, title = title, body = body }
end

function pre_confirm_flow.enter(state, intent)
  local current_model = runtime_state.get_ui_model(state)
  local choice = current_model and current_model.choice or nil
  if not choice or not choice.id then
    return false
  end
  if not _can_local_owner_open_pre_confirm(state, choice) then
    return false
  end

  local params = _resolve_enter_params(state, intent, choice)
  if not params then
    return false
  end

  state._pre_confirm_active = true
  state._pre_confirm_source_screen = params.source_screen
  local modal = _modal_ports(state)
  if type(modal.open_pre_confirm_screen) ~= "function" then
    return false
  end
  modal.open_pre_confirm_screen(state, choice, params.option_id, params.title, params.body)
  return true
end

function pre_confirm_flow.cancel(state)
  state._pre_confirm_active = nil
  local source = state._pre_confirm_source_screen
  state._pre_confirm_source_screen = nil
  runtime_state.set_pending_choice_id(state, nil)

  local current_model = runtime_state.get_ui_model(state)
  local choice = current_model and current_model.choice or nil
  if not choice then
    return
  end

  local modal = _modal_ports(state)
  if source == "base_inline" or source == nil then
    if type(modal.close_choice_modal) == "function" then
      modal.close_choice_modal(state)
    end
  else
    if type(modal.open_choice_modal) == "function" then
      modal.open_choice_modal(state, choice)
    end
  end
end

return pre_confirm_flow
