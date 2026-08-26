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

local function _state_ports(ports)
  return ports and ports.state or nil
end

local function _apply_lock_enabled(state_ports, state, enabled, turn_runtime)
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

function turn_role_control_policy.sync(game, state, ports)
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  local state_ports = _state_ports(ports)
  if not state or not state_ports or not state_ports.apply_role_control_lock then
    return
  end

  _apply_lock_enabled(state_ports, state, _resolve_role_control_lock_enabled(game), turn_runtime)
end

return turn_role_control_policy

--[[ mutate4lua-manifest
version=4
projectHash=fcad9cbeda009f61
scope.0.id=chunk:src/turn/policies/role_control.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=43
scope.0.semanticHash=8499fdfad55443b1
scope.1.id=function:_resolve_role_control_lock_enabled
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=14
scope.1.semanticHash=cb0c6c46a5281881
scope.2.id=function:_state_ports
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=18
scope.2.semanticHash=616a2ca60599c94f
scope.3.id=function:_apply_lock_enabled
scope.3.kind=function
scope.3.startLine=20
scope.3.endLine=30
scope.3.semanticHash=4b275ee2522d9180
scope.4.id=function:turn_role_control_policy.sync
scope.4.kind=function
scope.4.startLine=32
scope.4.endLine=40
scope.4.semanticHash=a7a08cb5c790a517
]]
