local logger = require("src.core.Logger")
local runtime = require("src.presentation.api.UIRuntimePort")
local turn_action_port = require("src.presentation.api.TurnActionPort")
local ui_view = require("src.presentation.api.UIViewService")
local canvas = require("src.presentation.interaction.UICanvasCoordinator")
local ui_events = require("src.presentation.shared.UIEvents")
local ui_event_state = require("src.presentation.interaction.UIEventState")
local local_actor_resolver = require("src.presentation.canvas_runtime.LocalActorResolver")
local choice_openers = require("src.presentation.ui.choice_screen_service.openers")
local choice_common = require("src.presentation.ui.choice_screen_service.common")
local number_utils = require("src.core.NumberUtils")

local intent_dispatcher = {}

local function _resolve_role_by_game_api(role_id)
  if role_id == nil then
    return nil
  end
  if not (GameAPI and type(GameAPI.get_role) == "function") then
    return nil
  end
  local ok, role = pcall(GameAPI.get_role, role_id)
  if not ok then
    return nil
  end
  return role
end

local function _resolve_role_by_id(role_id)
  if role_id == nil then
    return runtime.get_client_role()
  end
  local roles = all_roles
  if type(roles) == "table" then
    for _, role in ipairs(roles) do
      if runtime.resolve_role_id(role) == role_id then
        return role
      end
    end
  end
  local role_from_game_api = _resolve_role_by_game_api(role_id)
  if role_from_game_api ~= nil then
    return role_from_game_api
  end
  return {
    get_roleid = function()
      return role_id
    end,
  }
end

local function _resolve_turn_action_port(state, opts)
  local override_port = opts and opts.turn_action_port or nil
  local state_port = state and state.turn_action_port or nil
  return turn_action_port.resolve(override_port or state_port)
end

local function _should_block_intent(state, intent, action_port)
  return action_port.should_block_action(state, intent)
end

local function _normalize_auto_intent(state, intent)
  local action = {}
  for k, v in pairs(intent) do
    action[k] = v
  end
  local local_role_id = local_actor_resolver.resolve_local(state)
  if local_role_id ~= nil then
    action.actor_role_id = local_role_id
  elseif action.actor_role_id == nil then
    logger.warn("auto intent missing actor_role_id")
    return nil
  end
  return action
end

-- pre-confirm helpers

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
  local option_id, option_label, title, body

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

function intent_dispatcher.dispatch(state, game, intent, opts)
  assert(intent ~= nil, "missing intent")
  local intent_type = intent.type
  local action_port = _resolve_turn_action_port(state, opts)
  if intent_type == "toggle_action_log" and intent_dispatcher.dispatch_view_command(state, intent) then
    return
  end
  if _should_block_intent(state, intent, action_port) then
    return
  end
  if not game then
    logger.warn("ui intent without game:", tostring(intent_type))
    return
  end

  if intent_dispatcher.dispatch_game_action(state, game, intent, opts, action_port) then
    return
  end

  intent_dispatcher.dispatch_view_command(state, intent)
end

function intent_dispatcher.dispatch_game_action(state, game, intent, opts, action_port)
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
      action = _normalize_auto_intent(state, intent)
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

function intent_dispatcher.dispatch_view_command(state, intent)
  local intent_type = intent and intent.type
  if not intent_type then
    return false
  end

  if intent_type == "toggle_action_log" then
    local ui = state and state.ui or nil
    if not ui then
      return true
    end
    local active_role = _resolve_role_by_id(intent.actor_role_id)
    runtime.with_client_role(active_role, function()
      ui.debug_log_enabled_override = nil
      local next_enabled = not ui_event_state.resolve_debug_enabled(state)
      ui_view.set_debug_visible(state, next_enabled)
      if active_role == nil then
        return
      end
      local role_id = runtime.resolve_role_id(active_role) or tostring(active_role)
      if type(ui.debug_visible_by_role) ~= "table" then
        ui.debug_visible_by_role = {}
      end
      if type(ui.debug_log_enabled_by_role) ~= "table" then
        ui.debug_log_enabled_by_role = {}
      end
      ui.debug_visible_by_role[role_id] = next_enabled
      ui.debug_log_enabled_by_role[role_id] = next_enabled
      if next_enabled and type(active_role.send_ui_custom_event) ~= "function" then
        logger.warn("toggle_action_log missing role event channel:", tostring(role_id))
      end
      if next_enabled then
        canvas.switch_for_role(ui, canvas.CANVAS_DEBUG, active_role)
      else
        local hide_event = ui_events.hide[canvas.CANVAS_DEBUG]
        if hide_event then
          ui_events.send_to_role(active_role, hide_event, {})
        end
      end
    end)
    return true
  end

  if intent_type == "market_select" then
    ui_view.select_market_option(state, intent.option_id)
    return true
  end

  if intent_type == "popup_confirm" then
    ui_view.close_popup(state)
    return true
  end

  return false
end

return intent_dispatcher
