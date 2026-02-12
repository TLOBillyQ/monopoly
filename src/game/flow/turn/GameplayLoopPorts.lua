local gameplay_loop_ports = {}

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
    reset_status_3d = function() end,
    sync_status_3d = function() end,
    install_event_handlers = function() end,
    on_bankruptcy_tiles_cleared = function() end,
  }
end

local base_ports = _resolve_base_ports()

function gameplay_loop_ports.resolve(override_ports)
  if not override_ports then
    return base_ports
  end
  local resolved = {}
  for key, fn in pairs(base_ports) do
    if type(override_ports[key]) == "function" then
      resolved[key] = override_ports[key]
    else
      resolved[key] = fn
    end
  end
  return resolved
end

return gameplay_loop_ports

