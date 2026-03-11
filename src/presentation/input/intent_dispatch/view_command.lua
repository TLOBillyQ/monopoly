local view_command_dispatcher = {}
local number_utils = require("src.core.utils.number_utils")

local function _resolve_loaded(name)
  return package.loaded[name]
end

local function _resolve_role_by_id(runtime, role_id)
  local normalized = role_id
  local host_runtime = _resolve_loaded("src.presentation.runtime.host")
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

local function _fallback_dispatch(state, intent)
  local intent_type = intent and intent.type or nil
  if intent_type == nil then
    return false
  end
  local ui_view = _resolve_loaded("src.presentation.runtime.view")
  if ui_view == nil then
    return false
  end
  if intent_type == "market_select" then
    ui_view.select_market_option(state, intent.option_id)
    return true
  end
  if intent_type == "popup_confirm" then
    ui_view.close_popup(state)
    return true
  end

  local runtime = _resolve_loaded("src.presentation.runtime.ui")
  if intent_type == "toggle_action_log" and runtime ~= nil then
    local actor_role_id = intent.actor_role_id
    if actor_role_id == nil then
      return true
    end
    local active_role = _resolve_role_by_id(runtime, actor_role_id)
    local visible_by_role = state.ui.debug_visible_by_role or {}
    local next_enabled = visible_by_role[actor_role_id] ~= true
    ui_view.set_debug_visible_for_role(state, active_role, next_enabled)
    local send_event = active_role and active_role.send_ui_custom_event
    if type(send_event) == "function" then
      local ok = pcall(send_event, next_enabled and "显示调试屏" or "隐藏调试屏", {})
      if not ok then
        pcall(send_event, active_role, next_enabled and "显示调试屏" or "隐藏调试屏", {})
      end
    else
      local logger = _resolve_loaded("src.core.utils.logger")
      if logger and type(logger.warn) == "function" then
        logger.warn("toggle_action_log missing role event channel:", tostring(actor_role_id))
      end
    end
    if runtime.set_client_role then
      runtime.set_client_role(nil)
    end
    return true
  end

  local target_choice_effects = _resolve_loaded("src.presentation.runtime.controllers.target_choice_effects")
  if target_choice_effects ~= nil then
    if intent_type == "target_unlock" then
      target_choice_effects.on_unlock(state)
      return true
    end
    if intent_type == "target_lock" then
      target_choice_effects.on_scene_pick(state, intent.option_id, intent.actor_role_id, {
        option_id = intent.option_id,
        actor_role_id = intent.actor_role_id,
      })
      return true
    end
  end
  return false
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
