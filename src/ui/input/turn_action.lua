local logger = require("src.foundation.log")

local turn_action_port = {}

local _default_turn_action_port = {
  dispatch_action = function()
    return { status = "rejected" }
  end,
  should_block_action = function()
    return false
  end,
}

local function _resolve_raw_port(state, opts)
  local override_port = opts and opts.turn_action_port or nil
  local state_port = state and state.turn_action_port or nil
  return override_port or state_port
end

local function _resolve_port_method(raw, method_name)
  if type(raw) == "table" and type(raw[method_name]) == "function" then
    return raw[method_name]
  end
  return _default_turn_action_port[method_name]
end

function turn_action_port.resolve(state, opts)
  local raw = _resolve_raw_port(state, opts)
  if type(raw) ~= "table" then
    return _default_turn_action_port
  end
  return {
    dispatch_action = _resolve_port_method(raw, "dispatch_action"),
    should_block_action = _resolve_port_method(raw, "should_block_action"),
  }
end

function turn_action_port.should_block(state, intent, action_port)
  return action_port.should_block_action(state, intent)
end

local function _resolve_local_actor_role_id(state)
  local ports = state and state.gameplay_loop_ports or nil
  local actor_context = ports and ports.actor_context or nil
  if actor_context and type(actor_context.resolve_local_actor_role_id) == "function" then
    return actor_context.resolve_local_actor_role_id(state)
  end
  return nil
end

function turn_action_port.normalize_auto_intent(state, intent)
  local action = {}
  for k, v in pairs(intent) do
    action[k] = v
  end
  if action.actor_role_id ~= nil then
    return action
  end
  local local_role_id = _resolve_local_actor_role_id(state)
  if local_role_id ~= nil then
    action.actor_role_id = local_role_id
  else
    logger.warn("auto intent missing actor_role_id")
    return nil
  end
  return action
end

return turn_action_port

--[[ mutate4lua-manifest
version=2
projectHash=f97ac10128989f27
scope.0.id=chunk:src/ui/input/turn_action.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=70
scope.0.semanticHash=de142e7c63be6fb1
scope.1.id=function:anonymous@6:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=8
scope.1.semanticHash=12b02a1e157ffb7e
scope.2.id=function:anonymous@9:9
scope.2.kind=function
scope.2.startLine=9
scope.2.endLine=11
scope.2.semanticHash=c168b2cdb12a737a
scope.3.id=function:_resolve_raw_port:14
scope.3.kind=function
scope.3.startLine=14
scope.3.endLine=18
scope.3.semanticHash=eda36450103ee679
scope.4.id=function:_resolve_port_method:20
scope.4.kind=function
scope.4.startLine=20
scope.4.endLine=25
scope.4.semanticHash=0d04f8524639c0bb
scope.5.id=function:turn_action_port.resolve:27
scope.5.kind=function
scope.5.startLine=27
scope.5.endLine=36
scope.5.semanticHash=d7172e1041278ed8
scope.6.id=function:turn_action_port.should_block:38
scope.6.kind=function
scope.6.startLine=38
scope.6.endLine=40
scope.6.semanticHash=783e379789b31443
scope.7.id=function:_resolve_local_actor_role_id:42
scope.7.kind=function
scope.7.startLine=42
scope.7.endLine=49
scope.7.semanticHash=2776f1aa77165bc3
]]
