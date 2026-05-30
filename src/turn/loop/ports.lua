local gameplay_loop_ports = {}
local number_utils = require("src.foundation.number")
local ui_sync_defaults = require("src.turn.output.ui_sync_defaults")
local output_state_adapter = require("src.turn.output.state_adapter")
local _tick_timeout = nil
local _tick_ui_sync = nil
local _noop = function() end
local _zero = function()
  return 0
end
local function _load_tick_timeout()
  if _tick_timeout then
    return _tick_timeout
  end
  _tick_timeout = require("src.turn.waits.timeout")
  return _tick_timeout
end
local function _load_tick_ui_sync()
  if _tick_ui_sync then
    return _tick_ui_sync
  end
  _tick_ui_sync = require("src.turn.waits.ui_sync")
  return _tick_ui_sync
end
local port_groups = {
  modal = {
    "close_choice_modal",
    "open_choice_modal",
    "close_popup",
  },
  anim = {
    "play_move_anim",
    "play_action_anim",
    "reset_status_3d",
    "sync_status_3d",
  },
  ui_sync = {
    "apply_input_lock",
    "step_choice_timeout",
    "step_modal_timeout",
    "update_countdown",
    "resolve_ui_gate",
    "build_model",
    "refresh_from_dirty",
    "follow_camera",
    "sync_camera_position",
    "get_ui_state",
    "is_input_blocked",
    "is_popup_active",
    "is_choice_active",
    "is_market_active",
    "get_popup_owner_index",
    "set_input_blocked",
  },
  debug = {
    "log_status",
    "sync_event_log",
    "resolve_event_log_enabled",
  },
  clock = {
    "wall_now_seconds",
    "wall_diff_seconds",
    "cpu_now_seconds",
    "cpu_diff_seconds",
  },
  state = {
    "apply_role_control_lock",
    "install_event_handlers",
    "on_bankruptcy_tiles_cleared",
  },
  output = {
    "invalidate_ui_model",
    "clear_ui_dirty",
    "is_ui_dirty",
    "sync_ui_model",
    "get_ui_model",
    "sync_pending_choice",
    "clear_pending_choice",
    "get_pending_choice",
    "get_pending_choice_id",
    "get_pending_choice_elapsed",
    "set_pending_choice_elapsed",
    "set_pending_choice_id",
    "sync_modal_timer",
    "get_modal_elapsed",
    "get_modal_ref",
  },
}
local group_names = {
  "modal",
  "anim",
  "ui_sync",
  "debug",
  "clock",
  "state",
  "output",
}
local function _build_noop_group(keys, overrides)
  local group = {}
  for _, key in ipairs(keys or {}) do
    group[key] = _noop
  end
  for key, fn in pairs(overrides or {}) do
    group[key] = fn
  end
  return group
end
local _clock_diff = number_utils.diff_or_zero
local function _base_ui_sync_ports()
  return ui_sync_defaults.build_base_ui_sync_ports(_load_tick_timeout, _load_tick_ui_sync)
end
local base_port_builders = {
  modal = function()
    return _build_noop_group(port_groups.modal)
  end,
  anim = function()
    return _build_noop_group(port_groups.anim)
  end,
  ui_sync = _base_ui_sync_ports,
  debug = function()
    return _build_noop_group(port_groups.debug, {
      resolve_event_log_enabled = function()
        return false
      end,
    })
  end,
  clock = function()
    return {
      wall_now_seconds = _zero,
      wall_diff_seconds = _clock_diff,
      cpu_now_seconds = _zero,
      cpu_diff_seconds = _clock_diff,
    }
  end,
  state = function()
    return _build_noop_group(port_groups.state)
  end,
  output = output_state_adapter.build_runtime_output_ports,
}
local function _resolve_base_ports()
  local resolved = {}
  for _, group_name in ipairs(group_names) do
    resolved[group_name] = base_port_builders[group_name]()
  end
  return resolved
end
local function _resolve_grouped_override(override_ports)
  if type(override_ports) ~= "table" then
    return nil
  end
  for _, group_name in ipairs(group_names) do
    if type(override_ports[group_name]) == "table" then
      return override_ports
    end
  end
  return nil
end
local function _has_legacy_flat_override(override_ports)
  if type(override_ports) ~= "table" then
    return false
  end
  for _, group_name in ipairs(group_names) do
    local keys = port_groups[group_name]
    for _, key in ipairs(keys) do
      if type(override_ports[key]) == "function" then
        return true
      end
    end
  end
  return false
end
local function _copy_group_ports(base_group, override_group, required_keys)
  local merged = {}
  for _, key in ipairs(required_keys) do
    local fn = base_group[key]
    if type(fn) ~= "function" then
      error("missing base port: " .. tostring(key))
    end
    if override_group and type(override_group[key]) == "function" then
      merged[key] = override_group[key]
    else
      merged[key] = fn
    end
  end
  if type(override_group) == "table" then
    for key, value in pairs(override_group) do
      if merged[key] == nil then
        merged[key] = value
      end
    end
  end
  return merged
end
local base_ports = _resolve_base_ports()
local function _build_resolved_ports(grouped_override)
  local resolved = {}
  for _, group_name in ipairs(group_names) do
    local base_group = base_ports[group_name]
    local override_group = grouped_override and grouped_override[group_name] or nil
   resolved[group_name] = _copy_group_ports(base_group, override_group, port_groups[group_name])
   end
   ui_sync_defaults.fill_ui_sync_defaults(resolved.ui_sync, base_ports.ui_sync)
   return resolved
end

local function _copy_array(values)
  local copied = {}
  for index, value in ipairs(values or {}) do
    copied[index] = value
  end
  return copied
end

local function _copy_port_groups()
  local copied = {}
  for group_name, keys in pairs(port_groups) do
    copied[group_name] = _copy_array(keys)
  end
  return copied
end

function gameplay_loop_ports.resolve(override_ports)
  if override_ports == nil then
    return _build_resolved_ports(nil)
  end
  if type(override_ports) ~= "table" then
    error("invalid gameplay_loop_ports override: expected table")
  end
  local grouped_override = _resolve_grouped_override(override_ports)
  if grouped_override then
    return _build_resolved_ports(grouped_override)
  end
  if _has_legacy_flat_override(override_ports) then
    error("legacy flat gameplay_loop_ports is not supported; use grouped ports: modal/anim/ui_sync/debug/clock/state")
  end
  return _build_resolved_ports(nil)
end

function gameplay_loop_ports.describe_contract()
  return {
    group_names = _copy_array(group_names),
    port_groups = _copy_port_groups(),
  }
end

gameplay_loop_ports._build_noop_group = _build_noop_group

return gameplay_loop_ports

--[[ mutate4lua-manifest
version=2
projectHash=bcbae0f32fa3226c
scope.0.id=chunk:src/turn/loop/ports.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=249
scope.0.semanticHash=454419d06bcf0a13
scope.1.id=function:anonymous@7:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=7
scope.1.semanticHash=b53995942fd14a6f
scope.2.id=function:anonymous@8:8
scope.2.kind=function
scope.2.startLine=8
scope.2.endLine=10
scope.2.semanticHash=f25f2cab992f7889
scope.3.id=function:_load_tick_timeout:11
scope.3.kind=function
scope.3.startLine=11
scope.3.endLine=17
scope.3.semanticHash=126332cfc4fc30c8
scope.4.id=function:_load_tick_ui_sync:18
scope.4.kind=function
scope.4.startLine=18
scope.4.endLine=24
scope.4.semanticHash=9b73a6f6bc86ec8e
scope.5.id=function:_base_ui_sync_ports:109
scope.5.kind=function
scope.5.startLine=109
scope.5.endLine=111
scope.5.semanticHash=b69fdda9bcf657dc
scope.6.id=function:anonymous@113:113
scope.6.kind=function
scope.6.startLine=113
scope.6.endLine=115
scope.6.semanticHash=e6507ddcbd16e0d9
scope.7.id=function:anonymous@116:116
scope.7.kind=function
scope.7.startLine=116
scope.7.endLine=118
scope.7.semanticHash=04a7e13b7660b391
scope.8.id=function:anonymous@122:122
scope.8.kind=function
scope.8.startLine=122
scope.8.endLine=124
scope.8.semanticHash=c168b2cdb12a737a
scope.9.id=function:anonymous@120:120
scope.9.kind=function
scope.9.startLine=120
scope.9.endLine=126
scope.9.semanticHash=04e283c66ee8f61f
scope.10.id=function:anonymous@127:127
scope.10.kind=function
scope.10.startLine=127
scope.10.endLine=134
scope.10.semanticHash=846851b87f50040f
scope.11.id=function:anonymous@135:135
scope.11.kind=function
scope.11.startLine=135
scope.11.endLine=137
scope.11.semanticHash=052c76825aaa1a65
scope.12.id=function:gameplay_loop_ports.resolve:222
scope.12.kind=function
scope.12.startLine=222
scope.12.endLine=237
scope.12.semanticHash=11160fe247a32e20
scope.13.id=function:gameplay_loop_ports.describe_contract:239
scope.13.kind=function
scope.13.startLine=239
scope.13.endLine=244
scope.13.semanticHash=242fbaa7e722f92c
]]
