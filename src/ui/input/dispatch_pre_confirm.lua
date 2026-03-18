local choice_support = require("src.ui.pres.choice_support")
local number_utils = require("src.core.utils.number_utils")
local runtime_state = require("src.ui.runtime.state")

local pre_confirm_flow = {}

local function _modal_ports(state)
  local ports = state and state.gameplay_loop_ports or nil
  return ports and ports.modal or {}
end

local function _parse_item_slot_index(intent)
  if intent.type ~= "ui_button" or not intent.id then
    return nil
  end
  return string.match(intent.id, "^item_slot_(%d+)$")
end

local function _resolve_item_slot_option(state, intent)
  local slot_str = _parse_item_slot_index(intent)
  if not slot_str then
    return nil, nil
  end
  local slot_index = number_utils.to_integer(slot_str)
  local item_ids = state.ui and state.ui.item_slot_item_ids or nil
  if not item_ids or not slot_index then
    return nil, nil
  end
  local item_id = item_ids[slot_index]
  if not item_id then
    return nil, nil
  end
  local current_model = runtime_state.get_ui_model(state)
  local choice = current_model and current_model.choice or nil
  local label = choice_support.resolve_option_label_by_id(choice, item_id)
  return item_id, label
end

local function _resolve_market_skin_option(state, intent)
  if intent.type ~= "market_confirm" then
    return nil, nil
  end
  local current_model = runtime_state.get_ui_model(state)
  local choice = current_model and current_model.choice or nil
  if choice_support.resolve_screen_key(choice) ~= "market" then
    return nil, nil
  end
  local product_id = number_utils.to_integer(intent.option_id)
  if product_id == nil then
    return nil, nil
  end
  local matched_option = nil
  for _, option in ipairs(choice.options or {}) do
    local option_id = number_utils.to_integer(option and option.id)
    if option_id == product_id then
      matched_option = option
      break
    end
  end
  if not (matched_option and matched_option.requires_pre_confirm == true) then
    return nil, nil
  end
  local option_id = intent.option_id
  local label = choice_support.resolve_option_label_by_id(choice, option_id)
  if label == nil then
    option_id = product_id
    label = choice_support.resolve_option_label_by_id(choice, option_id)
  end
  return option_id, label
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
    if screen_key == "secondary_confirm" or screen_key == "market" or screen_key == "target" then
      return false
    end
    return screen_key ~= nil
  end

  if intent_type == "ui_button" and _parse_item_slot_index(intent) then
    return choice_support.requires_item_slot_pre_confirm(choice)
  end
  if intent_type == "market_confirm" then
    local option_id = _resolve_market_skin_option(state, intent)
    return option_id ~= nil
  end

  return false
end

function pre_confirm_flow.enter(state, intent)
  local current_model = runtime_state.get_ui_model(state)
  local choice = current_model and current_model.choice or nil
  if not choice or not choice.id then
    return false
  end

  local source_screen = state.ui and state.ui.active_choice_screen_key or nil
  local option_id
  local option_label
  local title
  local body

  if intent.type == "choice_select" then
    option_id = intent.option_id
    option_label = choice_support.resolve_option_label_by_id(choice, option_id) or tostring(option_id)
    title = choice_support.resolve_secondary_confirm_title(choice, state.game, source_screen, option_id)
    body = choice_support.resolve_secondary_confirm_body(choice, state.game, source_screen, option_id, option_label)
  elseif intent.type == "market_confirm" then
    source_screen = "market"
    option_id, option_label = _resolve_market_skin_option(state, intent)
    if not option_id then
      return false
    end
    title = choice_support.resolve_secondary_confirm_title(choice, state.game, source_screen, option_id)
    body = choice_support.resolve_secondary_confirm_body(choice, state.game, source_screen, option_id, option_label)
  elseif intent.type == "ui_button" then
    source_screen = "base_inline"
    option_id, option_label = _resolve_item_slot_option(state, intent)
    if not option_id then
      return false
    end
    title = choice_support.resolve_secondary_confirm_title(choice, state.game, source_screen, option_id)
    body = choice_support.resolve_secondary_confirm_body(choice, state.game, source_screen, option_id, option_label)
  else
    return false
  end

  state._pre_confirm_active = true
  state._pre_confirm_source_screen = source_screen
  local modal = _modal_ports(state)
  if type(modal.open_pre_confirm_screen) ~= "function" then
    return false
  end
  modal.open_pre_confirm_screen(state, choice, option_id, title, body)
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
