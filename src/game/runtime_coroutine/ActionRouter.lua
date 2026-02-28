local signals = require("src.game.runtime_coroutine.Signals")

local action_router = {}

function action_router.from_action(action)
  if not action then
    return nil
  end
  return {
    type = signals.ACTION,
    action = action,
  }
end

function action_router.tick(dt)
  return {
    type = signals.TICK,
    dt = dt or 0,
  }
end

return action_router
