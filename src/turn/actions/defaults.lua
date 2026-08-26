local number_utils = require("src.foundation.number")

local next_turn_cooldown = 0.4

local default_ui_sync_ports = {
  resolve_ui_gate = function()
    return nil
  end,
}

local default_clock_ports = {
  wall_now_seconds = function()
    return 0
  end,
  wall_diff_seconds = number_utils.diff_or_zero,
}

local function _loop_ports(state)
  return state and (state._resolved_gameplay_loop_ports or state.gameplay_loop_ports) or nil
end

local function _group_of(resolved, key)
  return type(resolved) == "table" and resolved[key] or nil
end

local function resolve_port_group(state, key)
  local group = _group_of(_loop_ports(state), key)
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

--[[ mutate4lua-manifest
version=4
projectHash=9c6fb501c543c2f2
scope.0.id=chunk:src/turn/actions/defaults.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=40
scope.0.semanticHash=0f445ba8c0b6868c
scope.1.id=function:<anonymous>
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=8
scope.1.semanticHash=d654da5e94a5e3f3
scope.2.id=function:<anonymous>#2
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=14
scope.2.semanticHash=f27a380acaa19c35
scope.3.id=function:_loop_ports
scope.3.kind=function
scope.3.startLine=18
scope.3.endLine=20
scope.3.semanticHash=d692619e49063104
scope.4.id=function:_group_of
scope.4.kind=function
scope.4.startLine=22
scope.4.endLine=24
scope.4.semanticHash=a6671db2ff301cf8
scope.5.id=function:resolve_port_group
scope.5.kind=function
scope.5.startLine=26
scope.5.endLine=32
scope.5.semanticHash=8327203e2b9cce01
]]
