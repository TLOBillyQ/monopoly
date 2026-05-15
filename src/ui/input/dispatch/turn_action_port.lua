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

function turn_action_port.resolve(state, opts)
  local override_port = opts and opts.turn_action_port or nil
  local state_port = state and state.turn_action_port or nil
  local raw = override_port or state_port
  if type(raw) ~= "table" then
    return _default_turn_action_port
  end
  return {
    dispatch_action = type(raw.dispatch_action) == "function" and raw.dispatch_action
      or _default_turn_action_port.dispatch_action,
    should_block_action = type(raw.should_block_action) == "function" and raw.should_block_action
      or _default_turn_action_port.should_block_action,
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
