local dirty_tracker = require("src.state.dirty_tracker")

local session = {}

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

function session.new(opts)
  return _build_session(opts)
end

-- Export for testability
session._mark_phase_default = _mark_phase_default

return session
