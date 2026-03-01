local logger = require("src.core.Logger")
local ui_view = require("src.presentation.api.UIViewService")
local choice_openers = require("src.presentation.ui.choice_screen_service.openers")
local choice_common = require("src.presentation.ui.choice_screen_service.common")
local number_utils = require("src.core.NumberUtils")

local game_action_dispatcher = {}

local function _parse_item_slot_index(intent)
  if intent.type ~= "ui_button" or not intent.id then
    return nil
  end
  return string.match(intent.id, "^item_slot_(%d+)$")
end

local function _needs_pre_confirm(state, intent)
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

local function _enter_pre_confirm(state, game, intent)
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
    option_label = choice_common.resolve_option_label_by_id(choice, option_id)
      or tostring(option_id)
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

local function _exit_pre_confirm_cancel(state)
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

function game_action_dispatcher.dispatch(state, game, intent, opts, action_port, turn_action_helpers)
  local intent_type = intent and intent.type
  if not intent_type then
    return false
  end

  -- item-phase ask: "是否使用道具？" confirm/cancel
  if state._item_phase_ask_active then
    if intent_type == "choice_select" then
      state._item_phase_ask_active = nil
      state._item_phase_confirmed = true
      ui_view.close_choice_modal(state)
      return true
    end
    if intent_type == "choice_cancel" then
      state._item_phase_ask_active = nil
      state._item_phase_confirmed = nil
      ui_view.close_choice_modal(state)
      local choice = state.ui_model and state.ui_model.choice or nil
      if choice and choice.id then
        action_port.dispatch_action(game, state, {
          type = "choice_cancel",
          choice_id = choice.id,
          actor_role_id = intent.actor_role_id,
        }, opts)
      end
      return true
    end
  end

  -- pre-confirm: confirmed action from secondary confirm screen
  if state._pre_confirm_active then
    if intent_type == "choice_select" then
      state._pre_confirm_active = nil
      state._pre_confirm_source_screen = nil
      action_port.dispatch_action(game, state, intent, opts)
      return true
    end
    if intent_type == "choice_cancel" then
      _exit_pre_confirm_cancel(state)
      return true
    end
  end

  -- pre-confirm: intercept fresh selection
  if not state._pre_confirm_active and _needs_pre_confirm(state, intent) then
    if _enter_pre_confirm(state, game, intent) then
      return true
    end
  end

  if intent_type == "ui_button"
      or intent_type == "choice_select"
      or intent_type == "choice_cancel" then
    local action = intent
    if intent_type == "ui_button" and intent.id == "auto" then
      action = turn_action_helpers.normalize_auto_intent(state, intent)
      if action == nil then
        return true
      end
    end
    action_port.dispatch_action(game, state, action, opts)
    return true
  end

  if intent_type == "market_confirm" then
    if not intent.choice_id or not intent.option_id then
      logger.warn("market_confirm missing ids:", tostring(intent.choice_id), tostring(intent.option_id))
      return true
    end
    action_port.dispatch_action(game, state, {
      type = "choice_select",
      choice_id = intent.choice_id,
      option_id = intent.option_id,
      actor_role_id = intent.actor_role_id,
    }, opts)
    return true
  end

  return false
end

return game_action_dispatcher
