local choice_openers = require("src.presentation.ui.choice_screen_service.openers")
local choice_common = require("src.presentation.ui.choice_screen_service.common")
local number_utils = require("src.core.NumberUtils")
local ui_view = require("src.presentation.api.UIViewService")

local pre_confirm_flow = {}

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
  local choice = state.ui_model and state.ui_model.choice or nil
  local label = choice_common.resolve_option_label_by_id(choice, item_id)
  return item_id, label
end

function pre_confirm_flow.needs_pre_confirm(state, intent)
  local intent_type = intent.type
  local ui = state.ui
  if not ui then
    return false
  end

  if intent_type == "choice_select" then
    local screen_key = ui.active_choice_screen_key
    if screen_key == "secondary_confirm" or screen_key == "market" then
      return false
    end
    return screen_key ~= nil
  end

  if intent_type == "ui_button" and _parse_item_slot_index(intent) then
    local choice = state.ui_model and state.ui_model.choice or nil
    return choice ~= nil and choice.kind == "item_phase_choice"
  end

  return false
end

function pre_confirm_flow.enter(state, intent)
  local choice = state.ui_model and state.ui_model.choice or nil
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
    option_label = choice_common.resolve_option_label_by_id(choice, option_id) or tostring(option_id)
    title = choice_common.resolve_pre_confirm_title(choice, source_screen)
    body = choice_common.resolve_pre_confirm_body(option_label)
  elseif intent.type == "ui_button" then
    source_screen = "base_inline"
    option_id, option_label = _resolve_item_slot_option(state, intent)
    if not option_id then
      return false
    end
    title = "使用道具"
    body = "确认使用 " .. (option_label or tostring(option_id)) .. "？"
  else
    return false
  end

  state._pre_confirm_active = true
  state._pre_confirm_source_screen = source_screen
  choice_openers.open_pre_confirm_screen(state, choice, option_id, title, body)
  return true
end

function pre_confirm_flow.cancel(state)
  state._pre_confirm_active = nil
  local source = state._pre_confirm_source_screen
  state._pre_confirm_source_screen = nil
  state.pending_choice_id = nil

  local choice = state.ui_model and state.ui_model.choice or nil
  if not choice then
    return
  end

  if source == "base_inline" or source == nil then
    ui_view.close_choice_modal(state)
  else
    ui_view.open_choice_modal(state, choice)
  end
end

return pre_confirm_flow
