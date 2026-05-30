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

--[[ mutate4lua-manifest
version=2
projectHash=1774420452b8ec87
scope.0.id=chunk:src/turn/timing.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=332
scope.0.semanticHash=14ec90584aaa7d5c
scope.1.id=function:M.from_action:14
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=20
scope.1.semanticHash=fec1c7f881a2c827
scope.2.id=function:_tick:22
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=25
scope.2.semanticHash=fc0ae30a67300c95
scope.3.id=function:_mark_phase_default:27
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=35
scope.3.semanticHash=87051ff98d560e52
scope.4.id=function:s:set_pending_action:60
scope.4.kind=function
scope.4.startLine=60
scope.4.endLine=66
scope.4.semanticHash=d026a0626fca2929
scope.5.id=function:s:peek_pending_action:68
scope.5.kind=function
scope.5.startLine=68
scope.5.endLine=73
scope.5.semanticHash=64c3c1a8efac6c07
scope.6.id=function:s:take_pending_action:75
scope.6.kind=function
scope.6.startLine=75
scope.6.endLine=82
scope.6.semanticHash=3fb85b7faae1a58a
scope.7.id=function:s:clear_pending_action:84
scope.7.kind=function
scope.7.startLine=84
scope.7.endLine=90
scope.7.semanticHash=3fc37449e1835829
scope.8.id=function:s:mark_phase:92
scope.8.kind=function
scope.8.startLine=92
scope.8.endLine=98
scope.8.semanticHash=0893949b031c8583
scope.9.id=function:s:create_script:100
scope.9.kind=function
scope.9.startLine=100
scope.9.endLine=104
scope.9.semanticHash=136815f97b4a5a3b
scope.10.id=function:s:reset_turn:106
scope.10.kind=function
scope.10.startLine=106
scope.10.endLine=115
scope.10.semanticHash=b695662b790666c9
scope.11.id=function:s:snapshot:119
scope.11.kind=function
scope.11.startLine=119
scope.11.endLine=127
scope.11.semanticHash=bea137f17aac2fe7
scope.12.id=function:_build_session:37
scope.12.kind=function
scope.12.startLine=37
scope.12.endLine=130
scope.12.semanticHash=71b22d05e8ea5062
scope.13.id=function:M.new:132
scope.13.kind=function
scope.13.startLine=132
scope.13.endLine=134
scope.13.semanticHash=f487fb4710b5e34f
scope.14.id=function:_resolve_phase_handler:148
scope.14.kind=function
scope.14.startLine=148
scope.14.endLine=154
scope.14.semanticHash=2d2b293937edd7c8
scope.15.id=function:_is_callable:156
scope.15.kind=function
scope.15.startLine=156
scope.15.endLine=167
scope.15.semanticHash=d6d0110cc15b3746
scope.16.id=function:_run_phase:169
scope.16.kind=function
scope.16.startLine=169
scope.16.endLine=181
scope.16.semanticHash=22b2800c36feb976
scope.17.id=function:_run_wait:183
scope.17.kind=function
scope.17.startLine=183
scope.17.endLine=189
scope.17.semanticHash=ed14dfc4dbe4fcba
scope.18.id=function:_set_current_state:191
scope.18.kind=function
scope.18.startLine=191
scope.18.endLine=194
scope.18.semanticHash=3096e93efba33932
scope.19.id=function:_yield_wait:198
scope.19.kind=function
scope.19.startLine=198
scope.19.endLine=202
scope.19.semanticHash=cd70ea71c13b168a
scope.20.id=function:_step_script:204
scope.20.kind=function
scope.20.startLine=204
scope.20.endLine=215
scope.20.semanticHash=7d0e7c4173f6cc4e
scope.21.id=function:_finish_script:217
scope.21.kind=function
scope.21.startLine=217
scope.21.endLine=222
scope.21.semanticHash=0837e365faa12deb
scope.22.id=function:_initial_state:224
scope.22.kind=function
scope.22.startLine=224
scope.22.endLine=226
scope.22.semanticHash=6c9a8eee91064678
scope.23.id=function:anonymous@230:230
scope.23.kind=function
scope.23.startLine=230
scope.23.endLine=238
scope.23.semanticHash=9eda922adce44180
scope.24.id=function:_is_action:242
scope.24.kind=function
scope.24.startLine=242
scope.24.endLine=244
scope.24.semanticHash=5a64066724f0415c
scope.25.id=function:_is_tick:246
scope.25.kind=function
scope.25.startLine=246
scope.25.endLine=248
scope.25.semanticHash=d261e672b358432c
scope.26.id=function:_ensure_queue:250
scope.26.kind=function
scope.26.startLine=250
scope.26.endLine=255
scope.26.semanticHash=2d74502534012273
scope.27.id=function:_ensure_script:257
scope.27.kind=function
scope.27.startLine=257
scope.27.endLine=266
scope.27.semanticHash=edc72fc157eec94d
scope.28.id=function:_apply_tick_to_session:268
scope.28.kind=function
scope.28.startLine=268
scope.28.endLine=273
scope.28.semanticHash=da383fba4d1dbedf
scope.29.id=function:_apply_signal_to_session:275
scope.29.kind=function
scope.29.startLine=275
scope.29.endLine=281
scope.29.semanticHash=ad784bcf6243a38a
scope.30.id=function:_try_early_return:283
scope.30.kind=function
scope.30.startLine=283
scope.30.endLine=303
scope.30.semanticHash=b9251d3e101230b6
scope.31.id=function:M.dispatch:305
scope.31.kind=function
scope.31.startLine=305
scope.31.endLine=312
scope.31.semanticHash=3a5e09d77db2b74f
]]
