local turn_logger = require("src.game.flow.turn.logger")
local await = require("src.game.flow.turn.await")

local turn_script = {}
local WAIT_HANDLERS = {
  wait_choice = await.choice,
  wait_move_anim = await.move_anim,
  wait_action_anim = await.action_anim,
  wait_landing_visual = await.landing_visual,
  detained_wait = await.detained,
  inter_turn_wait = await.inter_turn,
}

local function _resolve_phase_handler(phases, state_name)
  local handler = phases[state_name]
  if handler ~= nil or state_name ~= "move_followup" then
    return handler
  end
  return require("src.game.flow.turn.move_followup").run
end

local function _is_callable(v)
  if type(v) == "function" then
    return true
  end
  if type(v) == "table" then
    local mt = getmetatable(v)
    if mt and type(mt.__call) == "function" then
      return true
    end
  end
  return false
end

local function _run_phase(session, state_name, args)
  local phases = session.phases
  assert(type(phases) == "table", "missing session phases")
  local handler = _resolve_phase_handler(phases, state_name)
  assert(_is_callable(handler), "missing phase handler: " .. tostring(state_name))
  if state_name == "start" then
    turn_logger.log_turn_start(session.game)
  end
  session:mark_phase(state_name)
  local turn_mgr = session.turn_mgr or session
  return handler(turn_mgr, args)
end

local function _run_wait(session, state_name, args)
  local handler = WAIT_HANDLERS[state_name]
  if handler == nil then
    return nil
  end
  return handler(session, args)
end

local function _set_current_state(session, state_name, state_args)
  session.current_state = state_name
  session.current_args = state_args
end

local function _yield_wait(session, state_name)
  session.wait_state = state_name
  coroutine.yield({ kind = "wait", wait_state = state_name })
end

local function _step_script(session, state_name, state_args)
  _set_current_state(session, state_name, state_args)
  local wait_res = _run_wait(session, state_name, state_args)
  if wait_res == nil then
    return _run_phase(session, state_name, state_args)
  end
  if wait_res.wait then
    _yield_wait(session, state_name)
    return state_name, state_args
  end
  return wait_res.next_state, wait_res.next_args
end

local function _finish_script(session)
  session.current_state = nil
  session.current_args = nil
  session.wait_state = nil
  session.finished = true
end

function turn_script.create(session)
  assert(session ~= nil, "missing script session")
  return coroutine.create(function()
    local state_name = session.current_state or "start"
    local state_args = session.current_args
    while state_name do
      state_name, state_args = _step_script(session, state_name, state_args)
    end
    _finish_script(session)
  end)
end

return turn_script
