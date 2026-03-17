local view_command_dispatcher = {}
local number_utils = require("src.core.utils.number_utils")

local function _resolve_loaded(name)
  local loaded = package.loaded[name]
  if loaded ~= nil then
    return loaded
  end
  local ok, module = pcall(require, name)
  if ok then
    return module
  end
  return nil
end

local function _resolve_role_by_id(runtime, role_id)
  local normalized = role_id
  local host_runtime = _resolve_loaded("src.host.eggy")
  if host_runtime and type(host_runtime.resolve_roles) == "function" and runtime and type(runtime.resolve_role_id) == "function" then
    for _, role in ipairs(host_runtime.resolve_roles() or {}) do
      if tostring(runtime.resolve_role_id(role)) == tostring(normalized) then
        return role
      end
    end
  end
  local game_api = _G.GameAPI
  if game_api and type(game_api.get_role) == "function" then
    local resolved = game_api.get_role(normalized)
    local normalized_int = number_utils.to_integer(normalized)
    if resolved == nil and normalized_int ~= nil then
      resolved = game_api.get_role(normalized_int)
    end
    if resolved ~= nil then
      return resolved
    end
  end
  return {
    get_roleid = function()
      return normalized
    end,
  }
end

local function _resolve_intent_type(intent)
  return intent and intent.type or nil
end

local function _handle_market_select(state, intent, market_controller)
  if market_controller == nil then
    return false
  end
  market_controller.select_market_option(state, intent.option_id)
  return true
end

local function _handle_popup_confirm(state, modal_controller)
  if modal_controller == nil then
    return false
  end
  modal_controller.close_popup(state)
  return true
end

local function _warn_missing_toggle_channel(actor_role_id)
  local logger = _resolve_loaded("src.core.utils.logger")
  if logger and type(logger.warn) == "function" then
    logger.warn("toggle_action_log missing role event channel:", tostring(actor_role_id))
  end
end

local function _emit_toggle_event(active_role, next_enabled)
  local send_event = active_role and active_role.send_ui_custom_event
  local event_name = next_enabled and "显示调试屏" or "隐藏调试屏"
  if type(send_event) == "function" then
    local ok = pcall(send_event, event_name, {})
    if not ok then
      pcall(send_event, active_role, event_name, {})
    end
    return true
  end
  return false
end

local function _handle_toggle_action_log(state, intent, debug_view)
  local runtime = _resolve_loaded("src.ui.render.runtime_ui")
  if runtime == nil or debug_view == nil then
    return false
  end
  local actor_role_id = intent.actor_role_id
  if actor_role_id == nil then
    return true
  end
  local active_role = _resolve_role_by_id(runtime, actor_role_id)
  local visible_by_role = state.ui.debug_visible_by_role or {}
  local next_enabled = visible_by_role[actor_role_id] ~= true
  debug_view.set_debug_visible_for_role(state, active_role, next_enabled)
  if not _emit_toggle_event(active_role, next_enabled) then
    _warn_missing_toggle_channel(actor_role_id)
  end
  if runtime.set_client_role then
    runtime.set_client_role(nil)
  end
  return true
end

local function _handle_target_unlock(state, target_choice_effects)
  if target_choice_effects == nil then
    return false
  end
  target_choice_effects.on_unlock(state)
  return true
end

local function _handle_target_lock(state, intent, target_choice_effects)
  if target_choice_effects == nil then
    return false
  end
  target_choice_effects.on_scene_pick(state, intent.option_id, intent.actor_role_id, {
    option_id = intent.option_id,
    actor_role_id = intent.actor_role_id,
  })
  return true
end

local function _fallback_dispatch(state, intent)
  local intent_type = _resolve_intent_type(intent)
  if intent_type == nil then
    return false
  end
  local market_controller = _resolve_loaded("src.ui.ctl.market_controller")
  local modal_controller = _resolve_loaded("src.ui.ctl.modal_controller")
  local debug_view = _resolve_loaded("src.ui.ctl.debug_view")
  local target_choice_effects = _resolve_loaded("src.ui.ctl.target_choice_effects")
  local handlers = {
    market_select = function()
      return _handle_market_select(state, intent, market_controller)
    end,
    popup_confirm = function()
      return _handle_popup_confirm(state, modal_controller)
    end,
    toggle_action_log = function()
      return _handle_toggle_action_log(state, intent, debug_view)
    end,
    target_unlock = function()
      return _handle_target_unlock(state, target_choice_effects)
    end,
    target_lock = function()
      return _handle_target_lock(state, intent, target_choice_effects)
    end,
  }
  local handler = handlers[intent_type]
  return handler and handler() or false
end

function view_command_dispatcher.dispatch(state, intent)
  local ports = state and state.gameplay_loop_ports or nil
  local view_command = ports and ports.view_command or nil
  if view_command and type(view_command.dispatch) == "function" then
    return view_command.dispatch(state, intent) == true
  end
  return _fallback_dispatch(state, intent)
end

return view_command_dispatcher
