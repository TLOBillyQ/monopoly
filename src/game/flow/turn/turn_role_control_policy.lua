local gameplay_rules = require("src.core.config.gameplay_rules")
local runtime_state = require("src.core.runtime_facade.runtime_state")

local turn_role_control_policy = {}

local function _resolve_role_control_lock_enabled(game)
  if gameplay_rules.role_control_lock_enabled ~= true then
    return false
  end
  if not game or game.finished then
    return false
  end
  return true
end

function turn_role_control_policy.sync(game, state, ports)
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  local state_ports = ports and ports.state or nil
  if not state or not state_ports or not state_ports.apply_role_control_lock then
    return
  end

  local enabled = _resolve_role_control_lock_enabled(game)
  if enabled then
    state_ports.apply_role_control_lock(state, true)
    turn_runtime.role_control_lock_active = true
    return
  end
  if turn_runtime.role_control_lock_active then
    state_ports.apply_role_control_lock(state, false)
    turn_runtime.role_control_lock_active = false
  end
end

return turn_role_control_policy
