local events = require("src.v2.domain.Events")

local turn_reducer = {}

local event_types = events.types

local function _ceil_non_negative(value)
  if value <= 0 then
    return 0
  end
  return math.ceil(value)
end

function turn_reducer.apply(state, event)
  local turn = state.turn
  local payload = event.payload or {}

  if event.type == event_types.turn_began then
    turn.turn_no = payload.turn_no or (turn.turn_no + 1)
    turn.last_dice = payload.dice
    if payload.next_seed ~= nil then
      state.rng_seed = payload.next_seed
    end
    return
  end

  if event.type == event_types.move_anim_queued then
    turn.seq.move = payload.seq or (turn.seq.move + 1)
    turn.move_anim = {
      seq = turn.seq.move,
      player_seat = payload.player_seat,
      from_index = payload.from_index,
      to_index = payload.to_index,
      steps = payload.steps,
    }
    turn.phase = "wait_move_anim"
    return
  end

  if event.type == event_types.move_anim_confirmed then
    turn.move_anim = nil
    if turn.phase == "wait_move_anim" then
      turn.phase = "post_move"
    end
    return
  end

  if event.type == event_types.choice_opened then
    turn.phase = "wait_choice"
    local choice = payload.choice
    if choice and choice.id then
      turn.seq.choice = choice.id
    else
      turn.seq.choice = turn.seq.choice + 1
    end
    return
  end

  if event.type == event_types.choice_resolved then
    if turn.phase == "wait_choice" then
      turn.phase = "post_choice"
    end
    return
  end

  if event.type == event_types.action_anim_queued then
    turn.seq.action = payload.seq or (turn.seq.action + 1)
    turn.action_anim = {
      seq = turn.seq.action,
      kind = payload.kind,
      tile_id = payload.tile_id,
      player_seat = payload.player_seat,
    }
    turn.phase = "wait_action_anim"
    return
  end

  if event.type == event_types.action_anim_confirmed then
    turn.action_anim = nil
    if turn.phase == "wait_action_anim" then
      turn.phase = "post_action"
    end
    return
  end

  if event.type == event_types.turn_finished then
    turn.current_seat = payload.next_seat or turn.current_seat
    turn.phase = "idle"
    turn.pending_interaction = nil
    turn.choice_deadline = nil
    turn.choice_remaining = nil
    turn.countdown_seconds = 0
    turn.countdown_active = false
    return
  end

  if event.type == event_types.match_frozen then
    if turn.frozen then
      return
    end
    turn.frozen = true
    turn.frozen_reason = payload.reason
    turn.frozen_seat = payload.seat
    if turn.choice_deadline ~= nil then
      local now = state.clock.now or 0
      turn.choice_remaining = turn.choice_deadline - now
      if turn.choice_remaining < 0 then
        turn.choice_remaining = 0
      end
      turn.choice_deadline = nil
    end
    return
  end

  if event.type == event_types.match_unfrozen then
    turn.frozen = false
    turn.frozen_reason = nil
    turn.frozen_seat = nil
    if turn.choice_remaining ~= nil then
      local now = state.clock.now or 0
      turn.choice_deadline = now + turn.choice_remaining
      turn.choice_remaining = nil
    end
    return
  end

  if event.type == event_types.clock_tick then
    local now = payload.now or state.clock.now or 0
    local old = state.clock.now or now
    state.clock.dt = now - old
    if state.clock.dt < 0 then
      state.clock.dt = 0
    end
    state.clock.now = now
    if turn.pending_interaction and not turn.frozen and turn.choice_deadline ~= nil then
      turn.countdown_active = true
      turn.countdown_seconds = _ceil_non_negative(turn.choice_deadline - now)
    else
      turn.countdown_active = false
      turn.countdown_seconds = 0
    end
    return
  end

  if event.type == event_types.reconnect_grace_set then
    local seat = payload.seat
    if seat ~= nil then
      state.reconnect.grace_until[seat] = payload.expires_at
    end
    return
  end
end

return turn_reducer
