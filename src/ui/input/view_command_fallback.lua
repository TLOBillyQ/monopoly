local roles = require("src.ui.input.view_command_roles")
local command_policy = require("src.ui.input.command_policy")

local fallback = {}

local function _resolve_loaded(name)
  local ok, module = pcall(require, name)
  if ok then
    return module
  end
  return nil
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
  local active_role = roles.resolve(runtime, actor_role_id)
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

function fallback.dispatch(state, intent)
  local handler_key = command_policy.fallback_handler(intent)
  if handler_key == nil then return false end
  local handler = _FALLBACK_HANDLERS[handler_key]
  if handler then return handler(state, intent) end
  return false
end

return fallback

--[[ mutate4lua-manifest
version=2
projectHash=562f4eaef2d250b3
scope.0.id=chunk:src/ui/input/view_command_fallback.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=137
scope.0.semanticHash=b70295f4eabc1149
scope.0.lastMutatedAt=2026-06-05T07:27:35Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=3
scope.0.lastMutationKilled=3
scope.1.id=function:_resolve_loaded:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=11
scope.1.semanticHash=4232c2e642166ef0
scope.1.lastMutatedAt=2026-06-05T07:27:35Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=1
scope.1.lastMutationKilled=1
scope.2.id=function:_handle_market_select:13
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=19
scope.2.semanticHash=874e83efc95c2a2e
scope.2.lastMutatedAt=2026-06-05T07:27:35Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=4
scope.2.lastMutationKilled=4
scope.3.id=function:_handle_popup_confirm:21
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=27
scope.3.semanticHash=9737a4a8035638ca
scope.3.lastMutatedAt=2026-06-05T07:27:35Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=4
scope.3.lastMutationKilled=4
scope.4.id=function:_dispatch_via_table:29
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=34
scope.4.semanticHash=1003a56e2d6ce97d
scope.4.lastMutatedAt=2026-06-05T07:27:35Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=5
scope.4.lastMutationKilled=5
scope.5.id=function:anonymous@37:37
scope.5.kind=function
scope.5.startLine=37
scope.5.endLine=41
scope.5.semanticHash=8aaf9b0a3a915a8b
scope.5.lastMutatedAt=2026-06-05T07:27:35Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=2
scope.5.lastMutationKilled=2
scope.6.id=function:_open_with_gallery_fallback:36
scope.6.kind=function
scope.6.startLine=36
scope.6.endLine=42
scope.6.semanticHash=37e99169d19de511
scope.7.id=function:anonymous@48:48
scope.7.kind=function
scope.7.startLine=48
scope.7.endLine=48
scope.7.semanticHash=5c32b244f199d69e
scope.7.lastMutatedAt=2026-06-05T07:27:35Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=1
scope.7.lastMutationKilled=1
scope.8.id=function:anonymous@49:49
scope.8.kind=function
scope.8.startLine=49
scope.8.endLine=49
scope.8.semanticHash=ad7a1f1d2b0eecd7
scope.8.lastMutatedAt=2026-06-05T07:27:35Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=1
scope.8.lastMutationKilled=1
scope.9.id=function:anonymous@50:50
scope.9.kind=function
scope.9.startLine=50
scope.9.endLine=50
scope.9.semanticHash=f9ecafadc9201d16
scope.9.lastMutatedAt=2026-06-05T07:27:35Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=1
scope.9.lastMutationKilled=1
scope.10.id=function:anonymous@55:55
scope.10.kind=function
scope.10.startLine=55
scope.10.endLine=55
scope.10.semanticHash=64ec349ac43e4e06
scope.10.lastMutatedAt=2026-06-05T07:27:35Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=1
scope.10.lastMutationKilled=1
scope.11.id=function:anonymous@60:60
scope.11.kind=function
scope.11.startLine=60
scope.11.endLine=60
scope.11.semanticHash=1f5710dcc8cbe6f6
scope.11.lastMutatedAt=2026-06-05T07:27:35Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=1
scope.11.lastMutationKilled=1
scope.12.id=function:_warn_missing_toggle_channel:63
scope.12.kind=function
scope.12.startLine=63
scope.12.endLine=68
scope.12.semanticHash=5d0213447f448581
scope.12.lastMutatedAt=2026-06-05T07:27:35Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=6
scope.12.lastMutationKilled=6
scope.13.id=function:_emit_toggle_event:70
scope.13.kind=function
scope.13.startLine=70
scope.13.endLine=81
scope.13.semanticHash=82efb2d3874a8b5d
scope.13.lastMutatedAt=2026-06-05T07:27:35Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=13
scope.13.lastMutationKilled=13
scope.14.id=function:_resolve_toggle_runtime:83
scope.14.kind=function
scope.14.startLine=83
scope.14.endLine=89
scope.14.semanticHash=d38b05df70370ace
scope.14.lastMutatedAt=2026-06-05T07:27:35Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=4
scope.14.lastMutationKilled=4
scope.15.id=function:_clear_toggle_runtime_role:91
scope.15.kind=function
scope.15.startLine=91
scope.15.endLine=95
scope.15.semanticHash=4025a468ca210fa1
scope.15.lastMutatedAt=2026-06-05T07:27:35Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=passed
scope.15.lastMutationSites=1
scope.15.lastMutationKilled=1
scope.16.id=function:_handle_toggle_action_log:97
scope.16.kind=function
scope.16.startLine=97
scope.16.endLine=115
scope.16.semanticHash=5f75fcc12fff5b73
scope.16.lastMutatedAt=2026-06-05T07:27:35Z
scope.16.lastMutationLane=behavior
scope.16.lastMutationStatus=passed
scope.16.lastMutationSites=15
scope.16.lastMutationKilled=15
scope.17.id=function:anonymous@118:118
scope.17.kind=function
scope.17.startLine=118
scope.17.endLine=118
scope.17.semanticHash=9def17f23dd3bc62
scope.17.lastMutatedAt=2026-06-05T07:27:35Z
scope.17.lastMutationLane=behavior
scope.17.lastMutationStatus=passed
scope.17.lastMutationSites=1
scope.17.lastMutationKilled=1
scope.18.id=function:anonymous@119:119
scope.18.kind=function
scope.18.startLine=119
scope.18.endLine=119
scope.18.semanticHash=7da874c6eea91004
scope.18.lastMutatedAt=2026-06-05T07:27:35Z
scope.18.lastMutationLane=behavior
scope.18.lastMutationStatus=passed
scope.18.lastMutationSites=1
scope.18.lastMutationKilled=1
scope.19.id=function:anonymous@120:120
scope.19.kind=function
scope.19.startLine=120
scope.19.endLine=120
scope.19.semanticHash=bff99141302c52b4
scope.19.lastMutatedAt=2026-06-05T07:27:35Z
scope.19.lastMutationLane=behavior
scope.19.lastMutationStatus=passed
scope.19.lastMutationSites=1
scope.19.lastMutationKilled=1
scope.20.id=function:anonymous@121:121
scope.20.kind=function
scope.20.startLine=121
scope.20.endLine=121
scope.20.semanticHash=fc3d525cf6eac061
scope.20.lastMutatedAt=2026-06-05T07:27:35Z
scope.20.lastMutationLane=behavior
scope.20.lastMutationStatus=passed
scope.20.lastMutationSites=1
scope.20.lastMutationKilled=1
scope.21.id=function:anonymous@122:122
scope.21.kind=function
scope.21.startLine=122
scope.21.endLine=122
scope.21.semanticHash=fc3d525cf6eac061
scope.21.lastMutatedAt=2026-06-05T07:27:35Z
scope.21.lastMutationLane=behavior
scope.21.lastMutationStatus=passed
scope.21.lastMutationSites=1
scope.21.lastMutationKilled=1
scope.22.id=function:anonymous@123:123
scope.22.kind=function
scope.22.startLine=123
scope.22.endLine=123
scope.22.semanticHash=bdcf46d3e75a1747
scope.22.lastMutatedAt=2026-06-05T07:27:35Z
scope.22.lastMutationLane=behavior
scope.22.lastMutationStatus=passed
scope.22.lastMutationSites=1
scope.22.lastMutationKilled=1
scope.23.id=function:anonymous@124:124
scope.23.kind=function
scope.23.startLine=124
scope.23.endLine=124
scope.23.semanticHash=bdcf46d3e75a1747
scope.23.lastMutatedAt=2026-06-05T07:27:35Z
scope.23.lastMutationLane=behavior
scope.23.lastMutationStatus=passed
scope.23.lastMutationSites=1
scope.23.lastMutationKilled=1
scope.24.id=function:anonymous@125:125
scope.24.kind=function
scope.24.startLine=125
scope.24.endLine=125
scope.24.semanticHash=fbd5f6127ca8814d
scope.24.lastMutatedAt=2026-06-05T07:27:35Z
scope.24.lastMutationLane=behavior
scope.24.lastMutationStatus=passed
scope.24.lastMutationSites=1
scope.24.lastMutationKilled=1
scope.25.id=function:fallback.dispatch:128
scope.25.kind=function
scope.25.startLine=128
scope.25.endLine=134
scope.25.semanticHash=039d9839ce578cc6
scope.25.lastMutatedAt=2026-06-05T07:27:35Z
scope.25.lastMutationLane=behavior
scope.25.lastMutationStatus=passed
scope.25.lastMutationSites=5
scope.25.lastMutationKilled=5
]]
