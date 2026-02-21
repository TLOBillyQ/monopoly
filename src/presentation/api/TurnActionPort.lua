local turn_action_port = {}

local _default_port = {
  dispatch_action = function()
    return { status = "rejected" }
  end,
  should_block_action = function()
    return false
  end,
}

function turn_action_port.resolve(port)
  if type(port) ~= "table" then
    return _default_port
  end
  return {
    dispatch_action = type(port.dispatch_action) == "function" and port.dispatch_action or _default_port.dispatch_action,
    should_block_action = type(port.should_block_action) == "function" and port.should_block_action or _default_port.should_block_action,
  }
end

return turn_action_port
