local view_command_dispatcher = {}
local number_utils = require("src.foundation.number")
local host_runtime_ports = require("src.ui.host_bridge")

local function _resolve_loaded(name)
  local ok, module = pcall(require, name)
  if ok then
    return module
  end
  return nil
end

local function _resolve_role_by_id(runtime, role_id)
  local normalized = role_id
  if host_runtime_ports and type(host_runtime_ports.resolve_roles) == "function" and runtime and type(runtime.resolve_role_id) == "function" then
    for _, role in ipairs(host_runtime_ports.resolve_roles() or {}) do
      if tostring(runtime.resolve_role_id(role)) == tostring(normalized) then
        return role
      end
    end
  end
  if host_runtime_ports and type(host_runtime_ports.resolve_role_with) == "function" then
    local resolved = host_runtime_ports.resolve_role_with(normalized)
    if resolved ~= nil then
      return resolved
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

local function _handle_market_select(state, intent, market)
  if market == nil then
    return false
  end
  market.select_market_option(state, intent.option_id)
  return true
end

local function _handle_popup_confirm(state, modal)
  if modal == nil then
    return false
  end
  modal.close_popup(state)
  return true
end

local function _dispatch_via_table(module, action_table, state, intent)
  if module == nil then return false end
  local act = action_table[intent and intent.type]
  if act == nil then return false end
  act(state, intent, module)
  return true
end

local function _open_skin_with_fallback(state, intent, panel)
  local gallery = _resolve_loaded("src.ui.coord.skin_gallery")
  if gallery then gallery.open_skin(state, intent.actor_role_id)
  else panel.open(state, intent.actor_role_id) end
end

local function _open_gallery_with_fallback(state, intent, atlas)
  local gallery = _resolve_loaded("src.ui.coord.skin_gallery")
  if gallery then gallery.open_gallery(state, intent.actor_role_id)
  else atlas.open(state, intent.actor_role_id) end
end

local _GALLERY_ACTIONS = {
  open_skin_panel     = function(s, i, g) g.open_skin(s, i.actor_role_id) end,
  open_gallery_panel  = function(s, i, g) g.open_gallery(s, i.actor_role_id) end,
  skin_gallery_action = function(s, i, g) g.handle_action(s, i.action, i.actor_role_id) end,
}

local _SKIN_PANEL_ACTIONS = {
  open_skin_panel   = _open_skin_with_fallback,
  skin_panel_action = function(s, i, p) p.handle_action(s, i.action, i.actor_role_id) end,
}

local _ITEM_ATLAS_ACTIONS = {
  open_gallery_panel = _open_gallery_with_fallback,
  item_atlas_action  = function(s, i, a) a.handle_action(s, i.action, i.actor_role_id) end,
}

local function _warn_missing_toggle_channel(actor_role_id)
  local logger = _resolve_loaded("src.foundation.log")
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

local function _handle_toggle_action_log(state, intent, event_log_view)
  local runtime = _resolve_loaded("src.ui.render.runtime_ui")
  if runtime == nil or event_log_view == nil then
    return false
  end
  local actor_role_id = intent.actor_role_id
  if actor_role_id == nil then
    return true
  end
  local active_role = _resolve_role_by_id(runtime, actor_role_id)
  local visible_by_role = state.ui.debug_visible_by_role or {}
  local next_enabled = visible_by_role[actor_role_id] ~= true
  event_log_view.set_event_log_visible_for_role(state, active_role, next_enabled)
  if not _emit_toggle_event(active_role, next_enabled) then
    _warn_missing_toggle_channel(actor_role_id)
  end
  if runtime.set_client_role then
    runtime.set_client_role(nil)
  end
  return true
end

local _FALLBACK_HANDLERS = {
  market_select       = function(s, i) return _handle_market_select(s, i, _resolve_loaded("src.ui.coord.market")) end,
  popup_confirm       = function(s, _) return _handle_popup_confirm(s, _resolve_loaded("src.ui.coord.modal")) end,
  toggle_action_log   = function(s, i) return _handle_toggle_action_log(s, i, _resolve_loaded("src.ui.coord.event_log_view")) end,
  open_skin_panel     = function(s, i) return _dispatch_via_table(_resolve_loaded("src.ui.coord.skin_panel"), _SKIN_PANEL_ACTIONS, s, i) end,
  skin_panel_action   = function(s, i) return _dispatch_via_table(_resolve_loaded("src.ui.coord.skin_panel"), _SKIN_PANEL_ACTIONS, s, i) end,
  open_gallery_panel  = function(s, i) return _dispatch_via_table(_resolve_loaded("src.ui.coord.item_atlas"), _ITEM_ATLAS_ACTIONS, s, i) end,
  item_atlas_action   = function(s, i) return _dispatch_via_table(_resolve_loaded("src.ui.coord.item_atlas"), _ITEM_ATLAS_ACTIONS, s, i) end,
  skin_gallery_action = function(s, i) return _dispatch_via_table(_resolve_loaded("src.ui.coord.skin_gallery"), _GALLERY_ACTIONS, s, i) end,
}

local function _fallback_dispatch(state, intent)
  local intent_type = intent and intent.type
  if intent_type == nil then return false end
  local handler = _FALLBACK_HANDLERS[intent_type]
  if handler then return handler(state, intent) end
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
