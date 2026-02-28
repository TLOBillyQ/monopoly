local await = require("src.game.runtime_coroutine.Await")
local session_factory = require("src.game.runtime_coroutine.Session")

local turn_waits = {}

function turn_waits.make_anim_wait(turn_mgr, state_name, anim_key, done_action_type)
  return function(args)
    local session = session_factory.from_turn_flow(turn_mgr)
    local res = await.move_anim(session, args or {}, {
      state_name = state_name,
      anim_key = anim_key,
      done_action_type = done_action_type,
    })
    if res.wait then
      return state_name, args
    end
    return res.next_state, res.next_args
  end
end

function turn_waits.wait_action_anim(turn_mgr, args)
  local session = session_factory.from_turn_flow(turn_mgr)
  local res = await.action_anim(session, args or {})
  if res.wait then
    return "wait_action_anim", args
  end
  return res.next_state, res.next_args
end

return turn_waits
