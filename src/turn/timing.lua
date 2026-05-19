local dirty_tracker = require("src.state.dirty_tracker")
local turn_decision = require("src.turn.waits.decision")
local await = require("src.turn.waits.await")
local move_followup = require("src.turn.phases.move_followup")

local M = {}

local SIGNAL_ACTION = "action"
local SIGNAL_TICK = "tick"

local _action_signal = { type = SIGNAL_ACTION, action = nil }
local _tick_signal = { type = SIGNAL_TICK, dt = 0 }

function M.from_action(action)
  if not action then
    return nil
  end
  _action_signal.action = action
  return _action_signal
end

local function _tick(dt)
  _tick_signal.dt = dt or 0
  return _tick_signal
end

local function _mark_phase_default(game, phase)
  if not (game and game.turn) then
    return
  end
  game.turn.phase = phase
  if game.dirty then
    dirty_tracker.mark(game.dirty, "turn")
  end
end

local function _build_session(opts)
  assert(type(opts) == "table", "missing session opts")
  assert(opts.game ~= nil, "missing session game")
  local s = {
    game = opts.game,
    phases = opts.phases,
    turn_mgr = opts.turn_mgr,
    script_factory = opts.script_factory,
    queue = {},
    script = nil,
    finished = false,
    wait_state = nil,
    current_state = "start",
    current_args = nil,
    choice_elapsed_seconds = 0,
    _pending_action = nil,
    _seconds_wait = {},
    _take_action = opts.take_action,
    _set_action = opts.set_action,
    _clear_action = opts.clear_action,
    _mark_phase = opts.mark_phase,
  }

  function s:set_pending_action(action)
    if self._set_action then
      self._set_action(action)
      return
    end
    self._pending_action = action
  end

  function s:peek_pending_action()
    if self._peek_action then
      return self._peek_action()
    end
    return self._pending_action
  end

  function s:take_pending_action()
    if self._take_action then
      return self._take_action()
    end
    local action = self._pending_action
    self._pending_action = nil
    return action
  end

  function s:clear_pending_action()
    if self._clear_action then
      self._clear_action()
      return
    end
    self._pending_action = nil
  end

  function s:mark_phase(phase)
    if self._mark_phase then
      self._mark_phase(phase)
      return
    end
    _mark_phase_default(self.game, phase)
  end

  function s:create_script()
    local factory = self.script_factory
    assert(type(factory) == "function", "missing session script_factory")
    return factory(self)
  end

  function s:reset_turn()
    self.current_state = "start"
    self.current_args = nil
    self.wait_state = nil
    self.finished = false
    self.script = nil
    self._seconds_wait = {}
    self.choice_elapsed_seconds = 0
    self:clear_pending_action()
  end

  local _snapshot = { wait_state = nil, current_state = nil, pending_choice_id = nil, choice_elapsed_seconds = 0 }

  function s:snapshot()
    local turn = self.game and self.game.turn or nil
    local pending_choice = turn and turn.pending_choice or nil
    _snapshot.wait_state = self.wait_state
    _snapshot.current_state = self.current_state
    _snapshot.pending_choice_id = pending_choice and pending_choice.id or nil
    _snapshot.choice_elapsed_seconds = self.choice_elapsed_seconds or 0
    return _snapshot
  end

  return s
end

function M.new(opts)
  return _build_session(opts)
end

M._mark_phase_default = _mark_phase_default

local WAIT_HANDLERS = {
  wait_action = await.action,
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
  return move_followup.run
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
    turn_decision.log_turn_start(session.game)
  end
  session:mark_phase(state_name)
  local turn_mgr = session.turn_mgr or session
  ---@cast handler function
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

local _yield_payload = { kind = "wait", wait_state = nil }

local function _yield_wait(session, state_name)
  session.wait_state = state_name
  _yield_payload.wait_state = state_name
  coroutine.yield(_yield_payload)
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

local function _initial_state(session)
  return session.current_state or "start"
end

function M.create(session)
  assert(session ~= nil, "missing script session")
  return coroutine.create(function()
    local state_name = _initial_state(session)
    local state_args = session.current_args
    while state_name do
      state_name, state_args = _step_script(session, state_name, state_args)
    end
    _finish_script(session)
  end)
end

local _step_result = { wait_state = nil, finished = false }

local function _is_action(signal)
  return type(signal) == "table" and signal.type == SIGNAL_ACTION
end

local function _is_tick(signal)
  return type(signal) == "table" and signal.type == SIGNAL_TICK
end

local function _ensure_queue(session)
  if type(session.queue) ~= "table" then
    session.queue = {}
  end
  return session.queue
end

local function _ensure_script(session)
  local co = session.script
  if co and coroutine.status(co) ~= "dead" then
    return co
  end
  session:reset_turn()
  co = session:create_script()
  session.script = co
  return co
end

local function _apply_tick_to_session(session, signal)
  local next_dt = signal.dt or 0
  if session.wait_state == "wait_choice" then
    session.choice_elapsed_seconds = (session.choice_elapsed_seconds or 0) + next_dt
  end
end

local function _apply_signal_to_session(session, signal)
  if _is_action(signal) then
    session:set_pending_action(signal.action)
  elseif _is_tick(signal) then
    _apply_tick_to_session(session, signal)
  end
end

local function _try_early_return(session, co, queue, ok, yielded)
  if not ok then error(yielded) end
  if coroutine.status(co) == "dead" then
    session.finished = true
    session.wait_state = nil
    _step_result.wait_state = nil
    _step_result.finished = true
    return _step_result
  end
  if type(yielded) == "table" and yielded.kind == "wait" then
    session.wait_state = yielded.wait_state
    if #queue == 0 then
      _step_result.wait_state = yielded.wait_state
      _step_result.finished = false
      return _step_result
    end
  else
    session.wait_state = nil
  end
  return nil
end

function M.dispatch(session, signal)
  assert(session ~= nil, "missing scheduler session")
  if signal == nil then
    return
  end
  local queue = _ensure_queue(session)
  queue[#queue + 1] = signal
end

function M.step(session, dt)
  assert(session ~= nil, "missing scheduler session")
  local co = _ensure_script(session)
  local queue = _ensure_queue(session)
  if #queue == 0 then queue[#queue + 1] = _tick(dt) end
  while #queue > 0 do
    local signal = table.remove(queue, 1)
    _apply_signal_to_session(session, signal)
    local ok, yielded = coroutine.resume(co, signal)
    local result = _try_early_return(session, co, queue, ok, yielded)
    if result then return result end
  end
  _step_result.wait_state = session.wait_state
  _step_result.finished = not not session.finished
  return _step_result
end

return M
