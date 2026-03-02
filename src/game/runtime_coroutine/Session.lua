local session = {}

local function _mark_phase_default(game, phase)
  if not (game and game.turn) then
    return
  end
  game.turn.phase = phase
  if game.dirty then
    game.dirty.turn = true
    game.dirty.any = true
  end
end

local function _build_session(opts)
  assert(type(opts) == "table", "missing session opts")
  assert(opts.game ~= nil, "missing session game")
  local s = {
    game = opts.game,
    phases = opts.phases,
    turn_mgr = opts.turn_mgr,
    queue = {},
    script = nil,
    finished = false,
    wait_state = nil,
    current_state = "start",
    current_args = nil,
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

  function s:reset_turn()
    self.current_state = "start"
    self.current_args = nil
    self.wait_state = nil
    self.finished = false
    self.script = nil
    self._seconds_wait = {}
    self:clear_pending_action()
  end

  function s:snapshot()
    local turn = self.game and self.game.turn or nil
    local pending_choice = turn and turn.pending_choice or nil
    return {
      wait_state = self.wait_state,
      current_state = self.current_state,
      pending_choice_id = pending_choice and pending_choice.id or nil,
    }
  end

  return s
end

function session.new(opts)
  return _build_session(opts)
end

return session
