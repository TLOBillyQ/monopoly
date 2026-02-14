local gameplay_loop_ports = {}
local port_types = require("src.game.flow.turn.GameplayLoopPortTypes")

local grouped_port_key_map = {
  close_choice_modal = { "modal", "close_choice_modal" },
  open_choice_modal = { "modal", "open_choice_modal" },
  close_popup = { "modal", "close_popup" },
  play_move_anim = { "anim", "play_move_anim" },
  play_action_anim = { "anim", "play_action_anim" },
  reset_status_3d = { "anim", "reset_status_3d" },
  sync_status_3d = { "anim", "sync_status_3d" },
  apply_input_lock = { "ui_sync", "apply_input_lock" },
  step_choice_timeout = { "ui_sync", "step_choice_timeout" },
  step_modal_timeout = { "ui_sync", "step_modal_timeout" },
  update_countdown = { "ui_sync", "update_countdown" },
  build_model = { "ui_sync", "build_model" },
  refresh_from_dirty = { "ui_sync", "refresh_from_dirty" },
  get_ui_state = { "ui_sync", "get_ui_state" },
  is_input_blocked = { "ui_sync", "is_input_blocked" },
  is_popup_active = { "ui_sync", "is_popup_active" },
  is_choice_active = { "ui_sync", "is_choice_active" },
  is_market_active = { "ui_sync", "is_market_active" },
  get_popup_owner_index = { "ui_sync", "get_popup_owner_index" },
  set_input_blocked = { "ui_sync", "set_input_blocked" },
  log_status = { "debug", "log_status" },
  sync_debug_log = { "debug", "sync_debug_log" },
  resolve_debug_enabled = { "debug", "resolve_debug_enabled" },
  apply_role_control_lock = { "state", "apply_role_control_lock" },
  install_event_handlers = { "state", "install_event_handlers" },
  on_bankruptcy_tiles_cleared = { "state", "on_bankruptcy_tiles_cleared" },
}

local function _resolve_base_ports()
  return {
    close_choice_modal = function() end,
    open_choice_modal = function() end,
    close_popup = function() end,
    apply_input_lock = function() end,
    apply_role_control_lock = function() end,
    play_move_anim = function() end,
    play_action_anim = function() end,
    step_choice_timeout = function() end,
    step_modal_timeout = function() end,
    update_countdown = function() end,
    build_model = function() return {} end,
    refresh_from_dirty = function() return false end,
    log_status = function() end,
    sync_debug_log = function() end,
    resolve_debug_enabled = function() return false end,
    reset_status_3d = function() end,
    sync_status_3d = function() end,
    install_event_handlers = function() end,
    on_bankruptcy_tiles_cleared = function() end,
    get_ui_state = function() return nil end,
    is_input_blocked = function() return false end,
    is_popup_active = function() return false end,
    is_choice_active = function() return false end,
    is_market_active = function() return false end,
    get_popup_owner_index = function() return nil end,
    set_input_blocked = function() end,
  }
end

local function _resolve_override_fn(override_ports, key)
  local direct = override_ports[key]
  if type(direct) == "function" then
    return direct
  end
  local mapping = grouped_port_key_map[key]
  if not mapping then
    return nil
  end
  local group_name, group_key = mapping[1], mapping[2]
  local group = override_ports[group_name]
  if type(group) ~= "table" then
    return nil
  end
  local fn = group[group_key]
  if type(fn) == "function" then
    return fn
  end
  return nil
end

local function _attach_group_ports(ports)
  ports.modal = {
    close_choice_modal = ports.close_choice_modal,
    open_choice_modal = ports.open_choice_modal,
    close_popup = ports.close_popup,
  }
  ports.anim = {
    play_move_anim = ports.play_move_anim,
    play_action_anim = ports.play_action_anim,
    reset_status_3d = ports.reset_status_3d,
    sync_status_3d = ports.sync_status_3d,
  }
  ports.ui_sync = {
    apply_input_lock = ports.apply_input_lock,
    step_choice_timeout = ports.step_choice_timeout,
    step_modal_timeout = ports.step_modal_timeout,
    update_countdown = ports.update_countdown,
    build_model = ports.build_model,
    refresh_from_dirty = ports.refresh_from_dirty,
    get_ui_state = ports.get_ui_state,
    is_input_blocked = ports.is_input_blocked,
    is_popup_active = ports.is_popup_active,
    is_choice_active = ports.is_choice_active,
    is_market_active = ports.is_market_active,
    get_popup_owner_index = ports.get_popup_owner_index,
    set_input_blocked = ports.set_input_blocked,
  }
  ports.debug = {
    log_status = ports.log_status,
    sync_debug_log = ports.sync_debug_log,
    resolve_debug_enabled = ports.resolve_debug_enabled,
  }
  ports.state = {
    apply_role_control_lock = ports.apply_role_control_lock,
    install_event_handlers = ports.install_event_handlers,
    on_bankruptcy_tiles_cleared = ports.on_bankruptcy_tiles_cleared,
  }
  return ports
end

local base_ports = _attach_group_ports(_resolve_base_ports())

function gameplay_loop_ports.resolve(override_ports)
  if not override_ports then
    return base_ports
  end
  local resolved = {}
  for _, key in ipairs(port_types.keys) do
    local fn = base_ports[key]
    if fn == nil then
      error("missing base port: " .. tostring(key))
    end
    local override_fn = _resolve_override_fn(override_ports, key)
    if override_fn ~= nil then
      resolved[key] = override_fn
    else
      resolved[key] = fn
    end
  end
  if resolved.get_ui_state == base_ports.get_ui_state then
    resolved.get_ui_state = function(state)
      return state and state.ui or nil
    end
  end
  if resolved.is_input_blocked == base_ports.is_input_blocked then
    resolved.is_input_blocked = function(state)
      local ui = resolved.get_ui_state(state)
      return ui and ui.input_blocked == true or false
    end
  end
  if resolved.is_popup_active == base_ports.is_popup_active then
    resolved.is_popup_active = function(state)
      local ui = resolved.get_ui_state(state)
      return ui and ui.popup_active == true or false
    end
  end
  if resolved.is_choice_active == base_ports.is_choice_active then
    resolved.is_choice_active = function(state)
      local ui = resolved.get_ui_state(state)
      return ui and ui.choice_active == true or false
    end
  end
  if resolved.is_market_active == base_ports.is_market_active then
    resolved.is_market_active = function(state)
      local ui = resolved.get_ui_state(state)
      return ui and ui.market_active == true or false
    end
  end
  if resolved.get_popup_owner_index == base_ports.get_popup_owner_index then
    resolved.get_popup_owner_index = function(state)
      local ui = resolved.get_ui_state(state)
      return ui and ui.popup_owner_index or nil
    end
  end
  if resolved.set_input_blocked == base_ports.set_input_blocked then
    resolved.set_input_blocked = function(state, blocked)
      local ui = resolved.get_ui_state(state)
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
  return _attach_group_ports(resolved)
end

return gameplay_loop_ports
