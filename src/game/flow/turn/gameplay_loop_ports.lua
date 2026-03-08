local gameplay_loop_ports = {}
local number_utils = require("src.core.utils.number_utils")
local ui_sync_defaults = require("src.game.flow.turn.gameplay_loop_ui_sync_defaults")
local output_state_adapter = require("src.game.flow.output_adapters.output_state_adapter")
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
  _tick_timeout = require("src.game.flow.turn.tick_timeout")
  return _tick_timeout
end
local function _load_tick_ui_sync()
  if _tick_ui_sync then
    return _tick_ui_sync
  end
  _tick_ui_sync = require("src.game.flow.turn.tick_ui_sync")
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
    "step_target_selection",
    "update_countdown",
    "resolve_ui_gate",
    "build_model",
    "refresh_from_dirty",
    "follow_camera",
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
    "sync_debug_log",
    "resolve_debug_enabled",
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
    "invalidate_ui",
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
local function _clock_diff(timestamp_1, timestamp_2)
  if number_utils.is_numeric(timestamp_1) and number_utils.is_numeric(timestamp_2) then
    return timestamp_1 - timestamp_2
  end
  return 0
end
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
      resolve_debug_enabled = function()
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
  output = output_state_adapter.build_base_output_ports,
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
  return merged
end
local function _fill_clock_defaults(clock_ports, base_clock_ports)
  for _, key in ipairs({ "wall_now_seconds", "wall_diff_seconds", "cpu_now_seconds", "cpu_diff_seconds" }) do
    if clock_ports[key] == base_clock_ports[key] then
      clock_ports[key] = base_clock_ports[key]
    end
  end
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
  _fill_clock_defaults(resolved.clock, base_ports.clock)
  return resolved
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
return gameplay_loop_ports
