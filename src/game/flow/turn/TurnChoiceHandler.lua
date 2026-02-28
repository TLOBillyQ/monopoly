local await = require("src.game.runtime_coroutine.Await")
local session_factory = require("src.game.runtime_coroutine.Session")

local choice_handler = {}

function choice_handler.handle_wait_choice(turn_flow, args)
  local session = session_factory.from_turn_flow(turn_flow)
  local res = await.choice(session, args or {})
  if res.wait then
    return "wait_choice", args
  end
  return res.next_state, res.next_args
end

return choice_handler
