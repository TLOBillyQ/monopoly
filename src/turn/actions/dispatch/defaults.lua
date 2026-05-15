local number_utils = require("src.foundation.number")

local next_turn_cooldown = 0.4

local default_ui_sync_ports = {
  get_ui_state = function(state)
    return state and state.ui or nil
  end,
  resolve_ui_gate = function()
    return nil
  end,
}

local default_clock_ports = {
  wall_now_seconds = function()
    return 0
  end,
  wall_diff_seconds = function(timestamp_1, timestamp_2)
    if number_utils.is_numeric(timestamp_1) and number_utils.is_numeric(timestamp_2) then
      return timestamp_1 - timestamp_2
    end
    return 0
  end,
}

local function resolve_port_group(state, key)
  local resolved = state and (state._resolved_gameplay_loop_ports or state.gameplay_loop_ports) or nil
  local group = type(resolved) == "table" and resolved[key] or nil
  if type(group) == "table" then
    return group
  end
  return nil
end

return {
  next_turn_cooldown = next_turn_cooldown,
  default_ui_sync_ports = default_ui_sync_ports,
  default_clock_ports = default_clock_ports,
  resolve_port_group = resolve_port_group,
}
