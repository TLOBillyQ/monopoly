local gameplay_loop_ports = {}
local number_utils = require("src.core.NumberUtils")

local _tick_timeout = nil
local _tick_ui_sync = nil

local function _load_tick_timeout()
  if _tick_timeout then
    return _tick_timeout
  end
  _tick_timeout = require("src.game.flow.turn.TickTimeout")
  return _tick_timeout
end

local function _load_tick_ui_sync()
  if _tick_ui_sync then
    return _tick_ui_sync
  end
  _tick_ui_sync = require("src.game.flow.turn.TickUISync")
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
    "now",
    "diff_seconds",
  },
  state = {
    "apply_role_control_lock",
    "install_event_handlers",
    "on_bankruptcy_tiles_cleared",
  },
}

local group_names = {
  "modal",
  "anim",
  "ui_sync",
  "debug",
  "clock",
  "state",
}

local function _base_modal_ports()
  return {
    close_choice_modal = function() end,
    open_choice_modal = function() end,
    close_popup = function() end,
  }
end

local function _base_anim_ports()
  return {
    play_move_anim = function() end,
    play_action_anim = function() end,
    reset_status_3d = function() end,
    sync_status_3d = function() end,
  }
end

local function _base_ui_sync_ports()
  return {
    apply_input_lock = function() end,
    step_choice_timeout = function(game, state, dt)
      local tick_timeout = _load_tick_timeout()
      tick_timeout.step_default_choice(game, state, dt)
    end,
    step_modal_timeout = function(game, state, dt)
      local tick_timeout = _load_tick_timeout()
      tick_timeout.step_default_modal(game, state, dt)
    end,
    update_countdown = function(game, state)
      local tick_ui_sync = _load_tick_ui_sync()
      tick_ui_sync.update_countdown(game, state)
    end,
    build_model = function() return {} end,
    refresh_from_dirty = function() return false end,
    follow_camera = function() return false end,
    get_ui_state = function() return nil end,
    is_input_blocked = function() return false end,
    is_popup_active = function() return false end,
    is_choice_active = function() return false end,
    is_market_active = function() return false end,
    get_popup_owner_index = function() return nil end,
    set_input_blocked = function() return false end,
  }
end

local function _base_debug_ports()
  return {
    log_status = function() end,
    sync_debug_log = function() end,
    resolve_debug_enabled = function() return false end,
  }
end

local function _base_clock_ports()
  return {
    wall_now_seconds = function()
      if GameAPI and type(GameAPI.get_timestamp) == "function" then
        local ok, ts = pcall(GameAPI.get_timestamp)
        if ok and number_utils.is_numeric(ts) then
          return ts
        end
      end
      return 0
    end,
    wall_diff_seconds = function(timestamp_1, timestamp_2)
      if number_utils.is_numeric(timestamp_1)
          and number_utils.is_numeric(timestamp_2)
          and GameAPI
          and type(GameAPI.get_timestamp_diff) == "function" then
        local ok, diff = pcall(GameAPI.get_timestamp_diff, timestamp_1, timestamp_2)
        if ok and number_utils.is_numeric(diff) then
          return diff
        end
      end
      if number_utils.is_numeric(timestamp_1) and number_utils.is_numeric(timestamp_2) then
        return timestamp_1 - timestamp_2
      end
      return 0
    end,
    cpu_now_seconds = function()
      if os and type(os.clock) == "function" then
        return os.clock()
      end
      return 0
    end,
    cpu_diff_seconds = function(timestamp_1, timestamp_2)
      if number_utils.is_numeric(timestamp_1) and number_utils.is_numeric(timestamp_2) then
        return timestamp_1 - timestamp_2
      end
      return 0
    end,
    now = function()
      return 0
    end,
    diff_seconds = function(timestamp_1, timestamp_2)
      if number_utils.is_numeric(timestamp_1) and number_utils.is_numeric(timestamp_2) then
        return timestamp_1 - timestamp_2
      end
      return 0
    end,
  }
end

local function _base_state_ports()
  return {
    apply_role_control_lock = function() end,
    install_event_handlers = function() end,
    on_bankruptcy_tiles_cleared = function() end,
  }
end

local function _resolve_base_ports()
  return {
    modal = _base_modal_ports(),
    anim = _base_anim_ports(),
    ui_sync = _base_ui_sync_ports(),
    debug = _base_debug_ports(),
    clock = _base_clock_ports(),
    state = _base_state_ports(),
  }
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

local function _fill_ui_sync_defaults(ui_sync_ports, base_ui_sync_ports)
  if ui_sync_ports.get_ui_state == base_ui_sync_ports.get_ui_state then
    ui_sync_ports.get_ui_state = function(state)
      return state and state.ui or nil
    end
  end
  if ui_sync_ports.is_input_blocked == base_ui_sync_ports.is_input_blocked then
    ui_sync_ports.is_input_blocked = function(state)
      local ui = ui_sync_ports.get_ui_state(state)
      return ui and ui.input_blocked == true or false
    end
  end
  if ui_sync_ports.is_popup_active == base_ui_sync_ports.is_popup_active then
    ui_sync_ports.is_popup_active = function(state)
      local ui = ui_sync_ports.get_ui_state(state)
      return ui and ui.popup_active == true or false
    end
  end
  if ui_sync_ports.is_choice_active == base_ui_sync_ports.is_choice_active then
    ui_sync_ports.is_choice_active = function(state)
      local ui = ui_sync_ports.get_ui_state(state)
      return ui and ui.choice_active == true or false
    end
  end
  if ui_sync_ports.is_market_active == base_ui_sync_ports.is_market_active then
    ui_sync_ports.is_market_active = function(state)
      local ui = ui_sync_ports.get_ui_state(state)
      return ui and ui.market_active == true or false
    end
  end
  if ui_sync_ports.get_popup_owner_index == base_ui_sync_ports.get_popup_owner_index then
    ui_sync_ports.get_popup_owner_index = function(state)
      local ui = ui_sync_ports.get_ui_state(state)
      return ui and ui.popup_owner_index or nil
    end
  end
  if ui_sync_ports.set_input_blocked == base_ui_sync_ports.set_input_blocked then
    ui_sync_ports.set_input_blocked = function(state, blocked)
      local ui = ui_sync_ports.get_ui_state(state)
      if not ui then
        return false
      end
      if ui.input_blocked == blocked then
        return false
      end
      ui.input_blocked = blocked
      return true
    end
  end
end

local function _fill_clock_defaults(clock_ports, base_clock_ports, override_clock_ports)
  local has_legacy_now = override_clock_ports and type(override_clock_ports.now) == "function"
  local has_legacy_diff = override_clock_ports and type(override_clock_ports.diff_seconds) == "function"

  if has_legacy_now and clock_ports.wall_now_seconds == base_clock_ports.wall_now_seconds then
    clock_ports.wall_now_seconds = override_clock_ports.now
  end
  if has_legacy_diff and clock_ports.wall_diff_seconds == base_clock_ports.wall_diff_seconds then
    clock_ports.wall_diff_seconds = override_clock_ports.diff_seconds
  end

  if clock_ports.now == base_clock_ports.now then
    clock_ports.now = clock_ports.wall_now_seconds
  end
  if clock_ports.diff_seconds == base_clock_ports.diff_seconds then
    clock_ports.diff_seconds = clock_ports.wall_diff_seconds
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
  _fill_ui_sync_defaults(resolved.ui_sync, base_ports.ui_sync)
  _fill_clock_defaults(resolved.clock, base_ports.clock, grouped_override and grouped_override.clock or nil)
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
