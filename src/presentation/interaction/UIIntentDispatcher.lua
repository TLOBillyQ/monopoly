local logger = require("src.core.Logger")
local runtime = require("src.presentation.api.UIRuntimePort")
local turn_action_port = require("src.presentation.api.TurnActionPort")
local ui_view = require("src.presentation.api.UIViewService")
local canvas = require("src.presentation.interaction.UICanvasCoordinator")
local ui_events = require("src.presentation.shared.UIEvents")
local ui_event_state = require("src.presentation.interaction.UIEventState")
local local_actor_resolver = require("src.presentation.canvas_runtime.LocalActorResolver")

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
