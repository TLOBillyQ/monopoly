local turn_logger = require("src.game.flow.turn.TurnLogger")
local await = require("src.game.runtime_coroutine.Await")

local turn_script = {}

local function _run_phase(session, state_name, args)
  local phases = session.phases
  assert(type(phases) == "table", "missing session phases")
  local handler = phases[state_name]
  assert(type(handler) == "function", "missing phase handler: " .. tostring(state_name))
  if state_name == "start" then
    turn_logger.log_turn_start(session.game)
  end
  session:mark_phase(state_name)
  local turn_mgr = session.turn_mgr or session
  return handler(turn_mgr, args)
end

local function _run_wait(session, state_name, args)
  if state_name == "wait_choice" then
    return await.choice(session, args)
  end
  if state_name == "wait_move_anim" then
    return await.move_anim(session, args)
  end
  if state_name == "wait_action_anim" then
    return await.action_anim(session, args)
  end
  if state_name == "detained_wait" then
    return await.detained(session, args)
  end
  return nil
end

function turn_script.create(session)
  assert(session ~= nil, "missing script session")
  return coroutine.create(function()
    local state_name = session.current_state or "start"
    local state_args = session.current_args
    while state_name do
      session.current_state = state_name
      session.current_args = state_args
      local wait_res = _run_wait(session, state_name, state_args)
      if wait_res then
        if wait_res.wait then
          session.wait_state = state_name
          coroutine.yield({ kind = "wait", wait_state = state_name })
        else
          state_name = wait_res.next_state
          state_args = wait_res.next_args
        end
      else
        state_name, state_args = _run_phase(session, state_name, state_args)
      end
    end
    session.current_state = nil
    session.current_args = nil
    session.wait_state = nil
    session.finished = true
  end)
end

return turn_script
