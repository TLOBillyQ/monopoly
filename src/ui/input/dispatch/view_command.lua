local view_command_dispatcher = {}
local number_utils = require("src.foundation.number")
local host_runtime_ports = require("src.ui.host_bridge")
local panel_interrupt = require("src.ui.coord.panel_interrupt")

local _PANEL_ID_BY_INTENT = {
  toggle_action_log = "action_log",
  open_skin_panel = "skin",
  open_gallery_panel = "gallery",
}

local function _resolve_loaded(name)
  local ok, module = pcall(require, name)
  if ok then
    return module
  end
  return nil
end

local function _resolve_role_from_runtime(runtime, normalized)
  if host_runtime_ports and type(host_runtime_ports.resolve_roles) == "function" and runtime and type(runtime.resolve_role_id) == "function" then
    for _, role in ipairs(host_runtime_ports.resolve_roles() or {}) do
      if tostring(runtime.resolve_role_id(role)) == tostring(normalized) then
        return role
      end
    end
  end
  return nil
end

local function _resolve_role_from_host(normalized)
  if host_runtime_ports and type(host_runtime_ports.resolve_role_with) == "function" then
    local resolved = host_runtime_ports.resolve_role_with(normalized)
    if resolved ~= nil then
      return resolved
    end
  end
  return nil
end

local function _resolve_role_from_game_api(normalized)
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
  return nil
end

local function _fallback_role(normalized)
  return {
    get_roleid = function()
      return normalized
    end,
  }
end

local function _resolve_role_by_id(runtime, role_id)
  local normalized = role_id
  return _resolve_role_from_runtime(runtime, normalized)
    or _resolve_role_from_host(normalized)
    or _resolve_role_from_game_api(normalized)
    or _fallback_role(normalized)
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
  act(state, intent, module)
  return true
end

local function _open_with_gallery_fallback(gallery_method)
  return function(state, intent, fallback_module)
    local gallery = _resolve_loaded("src.ui.coord.skin_gallery")
    if gallery then gallery[gallery_method](state, intent.actor_role_id)
    else fallback_module.open(state, intent.actor_role_id) end
  end
end

local _open_skin_with_fallback = _open_with_gallery_fallback("open_skin")
local _open_gallery_with_fallback = _open_with_gallery_fallback("open_gallery")

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
  local logger_module = _resolve_loaded("src.foundation.log")
  if logger_module and type(logger_module.warn) == "function" then
    logger_module.warn("toggle_action_log missing role event channel:", tostring(actor_role_id))
  end
end

local function _emit_toggle_event(active_role, next_enabled)
  local send_event = active_role and active_role.send_ui_custom_event
  local event_name = next_enabled and "显示日志屏" or "隐藏日志屏"
  if type(send_event) == "function" then
    local ok = pcall(send_event, event_name, {})
    if not ok then
      pcall(send_event, active_role, event_name, {})
    end
    return true
  end
  return false
end

local function _resolve_toggle_runtime(event_log_view)
  local runtime = _resolve_loaded("src.ui.render.runtime_ui")
  if runtime == nil or event_log_view == nil then
    return nil
  end
  return runtime
end

local function _clear_toggle_runtime_role(runtime)
  if runtime.set_client_role then
    runtime.set_client_role(nil)
  end
end

local function _handle_toggle_action_log(state, intent, event_log_view)
  local runtime = _resolve_toggle_runtime(event_log_view)
  if runtime == nil then
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
  _clear_toggle_runtime_role(runtime)
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

local function _intent_panel_id(intent)
  return _PANEL_ID_BY_INTENT[intent and intent.type]
end

local function _dispatch_via_ports(state, intent)
  local ports = state and state.gameplay_loop_ports or nil
  local view_command = ports and ports.view_command or nil
  if view_command == nil or type(view_command.dispatch) ~= "function" then
    return nil
  end
  return view_command.dispatch(state, intent) == true
end

local function _blocks_panel_entry(state, intent)
  local panel_id = _intent_panel_id(intent)
  if panel_id == nil then
    return false
  end
  return panel_interrupt.block_entry(state, panel_id, intent.actor_role_id) == true
end

function view_command_dispatcher.dispatch(state, intent)
  if _blocks_panel_entry(state, intent) then
    return true
  end
  local port_result = _dispatch_via_ports(state, intent)
  if port_result ~= nil then
    return port_result
  end
  return _fallback_dispatch(state, intent)
end

return view_command_dispatcher

--[[ mutate4lua-manifest
version=2
projectHash=1213987eb3780534
scope.0.id=chunk:src/ui/input/dispatch/view_command.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=228
scope.0.semanticHash=4b530ff5f719f8db
scope.0.lastMutatedAt=2026-05-29T07:52:49Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=21
scope.0.lastMutationKilled=21
scope.1.id=function:_resolve_loaded:12
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=18
scope.1.semanticHash=4232c2e642166ef0
scope.2.id=function:_resolve_role_from_host:31
scope.2.kind=function
scope.2.startLine=31
scope.2.endLine=39
scope.2.semanticHash=4ae9b60695dc705b
scope.2.lastMutatedAt=2026-05-23T16:22:35Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=6
scope.2.lastMutationKilled=6
scope.3.id=function:_resolve_role_from_game_api:41
scope.3.kind=function
scope.3.startLine=41
scope.3.endLine=54
scope.3.semanticHash=400e29bab9a52679
scope.3.lastMutatedAt=2026-05-23T16:22:35Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=11
scope.3.lastMutationKilled=11
scope.4.id=function:anonymous@58:58
scope.4.kind=function
scope.4.startLine=58
scope.4.endLine=60
scope.4.semanticHash=c06cb8f90f07e1f0
scope.4.lastMutatedAt=2026-05-23T16:22:35Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=no_sites
scope.4.lastMutationSites=0
scope.4.lastMutationKilled=0
scope.5.id=function:_fallback_role:56
scope.5.kind=function
scope.5.startLine=56
scope.5.endLine=62
scope.5.semanticHash=2db49b8f76cb9648
scope.5.lastMutatedAt=2026-05-23T16:22:35Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=no_sites
scope.5.lastMutationSites=0
scope.5.lastMutationKilled=0
scope.6.id=function:_resolve_role_by_id:64
scope.6.kind=function
scope.6.startLine=64
scope.6.endLine=70
scope.6.semanticHash=84346529836acea6
scope.6.lastMutatedAt=2026-05-23T16:22:35Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=7
scope.6.lastMutationKilled=7
scope.7.id=function:_handle_market_select:72
scope.7.kind=function
scope.7.startLine=72
scope.7.endLine=78
scope.7.semanticHash=874e83efc95c2a2e
scope.7.lastMutatedAt=2026-05-23T16:22:35Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=4
scope.7.lastMutationKilled=4
scope.8.id=function:_handle_popup_confirm:80
scope.8.kind=function
scope.8.startLine=80
scope.8.endLine=86
scope.8.semanticHash=9737a4a8035638ca
scope.8.lastMutatedAt=2026-05-23T16:22:35Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=4
scope.8.lastMutationKilled=4
scope.9.id=function:_dispatch_via_table:88
scope.9.kind=function
scope.9.startLine=88
scope.9.endLine=93
scope.9.semanticHash=1003a56e2d6ce97d
scope.9.lastMutatedAt=2026-05-23T16:22:35Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=5
scope.9.lastMutationKilled=5
scope.10.id=function:anonymous@96:96
scope.10.kind=function
scope.10.startLine=96
scope.10.endLine=100
scope.10.semanticHash=8aaf9b0a3a915a8b
scope.10.lastMutatedAt=2026-05-23T16:22:35Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=2
scope.10.lastMutationKilled=2
scope.11.id=function:_open_with_gallery_fallback:95
scope.11.kind=function
scope.11.startLine=95
scope.11.endLine=101
scope.11.semanticHash=37e99169d19de511
scope.11.lastMutatedAt=2026-05-23T16:22:35Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=no_sites
scope.11.lastMutationSites=0
scope.11.lastMutationKilled=0
scope.12.id=function:anonymous@107:107
scope.12.kind=function
scope.12.startLine=107
scope.12.endLine=107
scope.12.semanticHash=5c32b244f199d69e
scope.12.lastMutatedAt=2026-05-23T16:22:35Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=1
scope.12.lastMutationKilled=1
scope.13.id=function:anonymous@108:108
scope.13.kind=function
scope.13.startLine=108
scope.13.endLine=108
scope.13.semanticHash=ad7a1f1d2b0eecd7
scope.13.lastMutatedAt=2026-05-23T16:22:35Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=1
scope.13.lastMutationKilled=1
scope.14.id=function:anonymous@109:109
scope.14.kind=function
scope.14.startLine=109
scope.14.endLine=109
scope.14.semanticHash=f9ecafadc9201d16
scope.14.lastMutatedAt=2026-05-23T16:22:35Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=1
scope.14.lastMutationKilled=1
scope.15.id=function:anonymous@114:114
scope.15.kind=function
scope.15.startLine=114
scope.15.endLine=114
scope.15.semanticHash=64ec349ac43e4e06
scope.15.lastMutatedAt=2026-05-23T16:22:35Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=passed
scope.15.lastMutationSites=1
scope.15.lastMutationKilled=1
scope.16.id=function:anonymous@119:119
scope.16.kind=function
scope.16.startLine=119
scope.16.endLine=119
scope.16.semanticHash=1f5710dcc8cbe6f6
scope.16.lastMutatedAt=2026-05-23T16:22:35Z
scope.16.lastMutationLane=behavior
scope.16.lastMutationStatus=passed
scope.16.lastMutationSites=1
scope.16.lastMutationKilled=1
scope.17.id=function:_warn_missing_toggle_channel:122
scope.17.kind=function
scope.17.startLine=122
scope.17.endLine=127
scope.17.semanticHash=5d0213447f448581
scope.17.lastMutatedAt=2026-05-29T07:44:17Z
scope.17.lastMutationLane=behavior
scope.17.lastMutationStatus=passed
scope.17.lastMutationSites=6
scope.17.lastMutationKilled=6
scope.18.id=function:_emit_toggle_event:129
scope.18.kind=function
scope.18.startLine=129
scope.18.endLine=140
scope.18.semanticHash=82efb2d3874a8b5d
scope.18.lastMutatedAt=2026-05-29T07:52:49Z
scope.18.lastMutationLane=behavior
scope.18.lastMutationStatus=passed
scope.18.lastMutationSites=13
scope.18.lastMutationKilled=13
scope.19.id=function:_resolve_toggle_runtime:142
scope.19.kind=function
scope.19.startLine=142
scope.19.endLine=148
scope.19.semanticHash=d38b05df70370ace
scope.19.lastMutatedAt=2026-05-23T16:22:35Z
scope.19.lastMutationLane=behavior
scope.19.lastMutationStatus=passed
scope.19.lastMutationSites=4
scope.19.lastMutationKilled=4
scope.20.id=function:_clear_toggle_runtime_role:150
scope.20.kind=function
scope.20.startLine=150
scope.20.endLine=154
scope.20.semanticHash=4025a468ca210fa1
scope.20.lastMutatedAt=2026-05-23T16:22:35Z
scope.20.lastMutationLane=behavior
scope.20.lastMutationStatus=passed
scope.20.lastMutationSites=1
scope.20.lastMutationKilled=1
scope.21.id=function:_handle_toggle_action_log:156
scope.21.kind=function
scope.21.startLine=156
scope.21.endLine=174
scope.21.semanticHash=ea1581c84ee5cc68
scope.21.lastMutatedAt=2026-05-23T16:22:35Z
scope.21.lastMutationLane=behavior
scope.21.lastMutationStatus=passed
scope.21.lastMutationSites=15
scope.21.lastMutationKilled=15
scope.22.id=function:anonymous@177:177
scope.22.kind=function
scope.22.startLine=177
scope.22.endLine=177
scope.22.semanticHash=9def17f23dd3bc62
scope.22.lastMutatedAt=2026-05-23T16:22:35Z
scope.22.lastMutationLane=behavior
scope.22.lastMutationStatus=passed
scope.22.lastMutationSites=1
scope.22.lastMutationKilled=1
scope.23.id=function:anonymous@178:178
scope.23.kind=function
scope.23.startLine=178
scope.23.endLine=178
scope.23.semanticHash=7da874c6eea91004
scope.23.lastMutatedAt=2026-05-23T16:22:35Z
scope.23.lastMutationLane=behavior
scope.23.lastMutationStatus=passed
scope.23.lastMutationSites=1
scope.23.lastMutationKilled=1
scope.24.id=function:anonymous@179:179
scope.24.kind=function
scope.24.startLine=179
scope.24.endLine=179
scope.24.semanticHash=bff99141302c52b4
scope.24.lastMutatedAt=2026-05-23T16:22:35Z
scope.24.lastMutationLane=behavior
scope.24.lastMutationStatus=passed
scope.24.lastMutationSites=1
scope.24.lastMutationKilled=1
scope.25.id=function:anonymous@180:180
scope.25.kind=function
scope.25.startLine=180
scope.25.endLine=180
scope.25.semanticHash=fc3d525cf6eac061
scope.25.lastMutatedAt=2026-05-23T16:22:35Z
scope.25.lastMutationLane=behavior
scope.25.lastMutationStatus=passed
scope.25.lastMutationSites=1
scope.25.lastMutationKilled=1
scope.26.id=function:anonymous@181:181
scope.26.kind=function
scope.26.startLine=181
scope.26.endLine=181
scope.26.semanticHash=fc3d525cf6eac061
scope.26.lastMutatedAt=2026-05-23T16:22:35Z
scope.26.lastMutationLane=behavior
scope.26.lastMutationStatus=passed
scope.26.lastMutationSites=1
scope.26.lastMutationKilled=1
scope.27.id=function:anonymous@182:182
scope.27.kind=function
scope.27.startLine=182
scope.27.endLine=182
scope.27.semanticHash=bdcf46d3e75a1747
scope.27.lastMutatedAt=2026-05-23T16:22:35Z
scope.27.lastMutationLane=behavior
scope.27.lastMutationStatus=passed
scope.27.lastMutationSites=1
scope.27.lastMutationKilled=1
scope.28.id=function:anonymous@183:183
scope.28.kind=function
scope.28.startLine=183
scope.28.endLine=183
scope.28.semanticHash=bdcf46d3e75a1747
scope.28.lastMutatedAt=2026-05-23T16:22:35Z
scope.28.lastMutationLane=behavior
scope.28.lastMutationStatus=passed
scope.28.lastMutationSites=1
scope.28.lastMutationKilled=1
scope.29.id=function:anonymous@184:184
scope.29.kind=function
scope.29.startLine=184
scope.29.endLine=184
scope.29.semanticHash=fbd5f6127ca8814d
scope.29.lastMutatedAt=2026-05-23T16:22:35Z
scope.29.lastMutationLane=behavior
scope.29.lastMutationStatus=passed
scope.29.lastMutationSites=1
scope.29.lastMutationKilled=1
scope.30.id=function:_fallback_dispatch:187
scope.30.kind=function
scope.30.startLine=187
scope.30.endLine=193
scope.30.semanticHash=058ba2f4175937b8
scope.30.lastMutatedAt=2026-05-23T16:22:35Z
scope.30.lastMutationLane=behavior
scope.30.lastMutationStatus=passed
scope.30.lastMutationSites=5
scope.30.lastMutationKilled=5
scope.31.id=function:_intent_panel_id:195
scope.31.kind=function
scope.31.startLine=195
scope.31.endLine=197
scope.31.semanticHash=7011b93f246294da
scope.31.lastMutatedAt=2026-05-23T16:22:35Z
scope.31.lastMutationLane=behavior
scope.31.lastMutationStatus=passed
scope.31.lastMutationSites=1
scope.31.lastMutationKilled=1
scope.32.id=function:_dispatch_via_ports:199
scope.32.kind=function
scope.32.startLine=199
scope.32.endLine=206
scope.32.semanticHash=8150b80ab9135464
scope.32.lastMutatedAt=2026-05-23T16:22:35Z
scope.32.lastMutationLane=behavior
scope.32.lastMutationStatus=passed
scope.32.lastMutationSites=12
scope.32.lastMutationKilled=12
scope.33.id=function:_blocks_panel_entry:208
scope.33.kind=function
scope.33.startLine=208
scope.33.endLine=214
scope.33.semanticHash=51c672a3215ccd5f
scope.33.lastMutatedAt=2026-05-23T16:22:35Z
scope.33.lastMutationLane=behavior
scope.33.lastMutationStatus=passed
scope.33.lastMutationSites=6
scope.33.lastMutationKilled=6
scope.34.id=function:view_command_dispatcher.dispatch:216
scope.34.kind=function
scope.34.startLine=216
scope.34.endLine=225
scope.34.semanticHash=85c0b68e9bd400a4
scope.34.lastMutatedAt=2026-05-23T16:22:35Z
scope.34.lastMutationLane=behavior
scope.34.lastMutationStatus=passed
scope.34.lastMutationSites=5
scope.34.lastMutationKilled=5
]]
