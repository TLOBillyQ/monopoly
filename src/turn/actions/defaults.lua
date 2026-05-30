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
  wall_diff_seconds = number_utils.diff_or_zero,
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

--[[ mutate4lua-manifest
version=2
projectHash=08c0fb80759b1c95
scope.0.id=chunk:src/turn/actions/defaults.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=36
scope.0.semanticHash=129b53a289f1257a
scope.1.id=function:anonymous@6:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=8
scope.1.semanticHash=dd830ebe796565dd
scope.2.id=function:anonymous@9:9
scope.2.kind=function
scope.2.startLine=9
scope.2.endLine=11
scope.2.semanticHash=d8269153568043a6
scope.3.id=function:anonymous@15:15
scope.3.kind=function
scope.3.startLine=15
scope.3.endLine=17
scope.3.semanticHash=f25f2cab992f7889
scope.4.id=function:resolve_port_group:21
scope.4.kind=function
scope.4.startLine=21
scope.4.endLine=28
scope.4.semanticHash=05cdbd1059c96318
]]
