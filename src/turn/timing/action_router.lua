local action_router = {}
local SIGNAL_ACTION = "action"
local SIGNAL_TICK = "tick"

local _action_signal = { type = SIGNAL_ACTION, action = nil }
local _tick_signal = { type = SIGNAL_TICK, dt = 0 }

function action_router.from_action(action)
  if not action then
    return nil
  end
  _action_signal.action = action
  return _action_signal
end

function action_router.tick(dt)
  _tick_signal.dt = dt or 0
  return _tick_signal
end

return action_router
