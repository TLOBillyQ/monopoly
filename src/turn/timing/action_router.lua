local action_router = {}
local SIGNAL_ACTION = "action"
local SIGNAL_TICK = "tick"

function action_router.from_action(action)
  if not action then
    return nil
  end
  return {
    type = SIGNAL_ACTION,
    action = action,
  }
end

function action_router.tick(dt)
  return {
    type = SIGNAL_TICK,
    dt = dt or 0,
  }
end

return action_router
