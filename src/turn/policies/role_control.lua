local debug_flags = require("src.config.gameplay.debug_flags")
local runtime_state = require("src.state.runtime")

local turn_role_control_policy = {}

local function _resolve_role_control_lock_enabled(game)
  if debug_flags.role_control_lock_enabled ~= true then
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

--[[ mutate4lua-manifest
version=2
projectHash=9364f074fa8d970c
scope.0.id=chunk:src/turn/policies/role_control.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=36
scope.0.semanticHash=245604a1109356d7
scope.1.id=function:_resolve_role_control_lock_enabled:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=14
scope.1.semanticHash=0d492f7a8d755cfd
scope.2.id=function:turn_role_control_policy.sync:16
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=33
scope.2.semanticHash=b606966fc5f6699d
]]
