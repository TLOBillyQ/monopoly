local turn_decision = require("src.game.flow.turn.decision")
local validator = require("src.game.flow.turn.dispatch_validator")
local number_utils = require("src.core.utils.number_utils")
local gameplay_rules = require("src.core.config.gameplay_rules")
local runtime_ports = require("src.core.ports.runtime_ports")
local landing_visual_hold = require("src.core.state_access.landing_visual_hold")
local logger = require("src.core.utils.logger")

local await = {}

local function _should_move_anim_debug_log()
  return logger.is_anim_debug_enabled() or gameplay_rules.move_anim_debug_log_enabled == true
end

local function _move_anim_debug_log(...)
  if not _should_move_anim_debug_log() then
    return
  end
  logger.info_unlimited("[MoveAnim]", ...)
end

local function _next(args)
  args = args or {}
  return args.next_state, args.next_args
end

local function _resolve_after_action_anim(args, res)
  local default_next_state, default_next_args = _next(args)
  local next_state, next_args = default_next_state, default_next_args
  local after_action_anim = type(res) == "table" and res.after_action_anim or nil
  if type(after_action_anim) ~= "table" then
    return next_state, next_args
  end
  next_state = after_action_anim.next_state or next_state
  next_args = after_action_anim.next_args or next_args
  if next_state == "move_followup" and type(next_args) == "table" then
    next_args.next_state = next_args.next_state or default_next_state
    next_args.next_args = next_args.next_args or default_next_args
  end
  return next_state, next_args
end

local function _mark_dirty(game)
  if game and game.dirty then
    game.dirty.turn = true
    game.dirty.any = true
  end
end

local function _next_action_anim(game)
  assert(game ~= nil and game.turn ~= nil, "missing game.turn")
  local queue = game.turn.action_anim_queue
  if type(queue) ~= "table" or #queue == 0 then
    return nil
  end
  local anim = table.remove(queue, 1)
  game.turn.action_anim = anim
  _mark_dirty(game)
  return anim
end

local function _await_anim_done(session, args, opts)
  assert(session ~= nil and session.game ~= nil, "missing await session")
  assert(opts ~= nil and opts.state_name ~= nil, "missing wait state_name")
  assert(opts.anim_key ~= nil, "missing wait anim_key")
  assert(opts.done_action_type ~= nil, "missing wait done_action_type")
  local game = session.game
  session:mark_phase(opts.state_name)

  local anim = game.turn[opts.anim_key]
  assert(anim ~= nil, "missing " .. tostring(opts.anim_key))

  local action = session:take_pending_action()
  if not action or action.type ~= opts.done_action_type then
    return { wait = true }
  end
  if action.seq and anim.seq and action.seq ~= anim.seq then
    return { wait = true }
  end
  game.turn[opts.anim_key] = nil
  _mark_dirty(game)
  local next_state, next_args = _next(args)
  return {
    next_state = next_state,
    next_args = next_args,
  }
end

function await.choice(session, args)
  assert(session ~= nil and session.game ~= nil, "missing await session")
  local game = session.game
  session:mark_phase("wait_choice")
  local choice = game.turn.pending_choice
  if not choice then
    session.choice_elapsed_seconds = 0
    session:clear_pending_action()
    local next_state, next_args = _next(args)
    return {
      next_state = next_state,
      next_args = next_args,
    }
  end

  local action = turn_decision.decide_choice_action(game, choice, session:take_pending_action(), {
    elapsed_seconds = session.choice_elapsed_seconds or 0,
  })
  if not action then
    return { wait = true }
  end
  if action.type == "choice_select" or action.type == "choice_cancel" then
    if not validator.validate_choice_id(action, choice) then
      return { wait = true }
    end
  end

  local res = turn_decision.resolve_choice(game, choice, action)
  if res and res.stay then
    return { wait = true }
  end

  session.choice_elapsed_seconds = 0

  local next_state, next_args = _resolve_after_action_anim(args, res)
  if game.turn.action_anim then
    if next_state == "move_followup" then
      game.turn.move_followup_pending = true
      _mark_dirty(game)
    end
    return {
      next_state = "wait_action_anim",
      next_args = {
        next_state = next_state,
        next_args = next_args,
      },
    }
  end

  return {
    next_state = next_state,
    next_args = next_args,
  }
end

function await.move_anim(session, args, opts)
  opts = opts or {}
  if _should_move_anim_debug_log() then
    local game = session and session.game or nil
    local anim = game and game.turn and game.turn[opts.anim_key or "move_anim"] or nil
    local action = session and session.peek_pending_action and session:peek_pending_action() or nil
    _move_anim_debug_log(
      "await_move_anim",
      "phase=" .. tostring(game and game.turn and game.turn.phase or "nil"),
      "anim_seq=" .. tostring(anim and anim.seq or "nil"),
      "pending_action_type=" .. tostring(action and action.type or "nil"),
      "pending_action_seq=" .. tostring(action and action.seq or "nil")
    )
  end
  return _await_anim_done(session, args, {
    state_name = opts.state_name or "wait_move_anim",
    anim_key = opts.anim_key or "move_anim",
    done_action_type = opts.done_action_type or "move_anim_done",
  })
end

function await.action_anim(session, args)
  assert(session ~= nil and session.game ~= nil, "missing await session")
  local game = session.game
  session:mark_phase("wait_action_anim")
  local anim = game.turn.action_anim
  if not anim then
    local next_anim = _next_action_anim(game)
    if next_anim then
      return { wait = true }
    end
    session:clear_pending_action()
    local next_state, next_args = _next(args)
    return {
      next_state = next_state,
      next_args = next_args,
    }
  end

  local action = session:take_pending_action()
  if not action or action.type ~= "action_anim_done" then
    return { wait = true }
  end
  if action.seq and anim.seq and action.seq ~= anim.seq then
    return { wait = true }
  end

  game.turn.action_anim = nil
  _mark_dirty(game)

  if _next_action_anim(game) then
    return { wait = true }
  end
  local next_state, next_args = _next(args)
  return {
    next_state = next_state,
    next_args = next_args,
  }
end

function await.landing_visual(session, args)
  assert(session ~= nil and session.game ~= nil, "missing await session")
  local game = session.game
  session:mark_phase("wait_landing_visual")
  local turn = assert(game.turn, "missing game.turn")

  if turn.landing_visual_wait_started ~= true then
    local seq = (turn.landing_visual_wait_seq or 0) + 1
    turn.landing_visual_wait_seq = seq
    turn.landing_visual_wait_started = true
    turn.landing_visual_wait_ready = false
    _mark_dirty(game)
    local delay = gameplay_rules.landing_visual_hold_seconds or 0
    runtime_ports.schedule(delay, function()
      if game and game.turn and game.turn.landing_visual_wait_seq == seq then
        game.turn.landing_visual_wait_ready = true
        _mark_dirty(game)
      end
    end)
    return { wait = true }
  end

  if turn.landing_visual_wait_ready ~= true then
    return { wait = true }
  end

  turn.landing_visual_wait_started = false
  turn.landing_visual_wait_ready = false
  turn.landing_visual_wait_seq = nil
  landing_visual_hold.mark_release_pending(game)
  local next_state, next_args = _next(args)
  return {
    next_state = next_state,
    next_args = next_args,
  }
end

function await.detained(session, args)
  assert(session ~= nil and session.game ~= nil, "missing await session")
  local game = session.game
  session:mark_phase("detained_wait")
  if game.turn.detained_wait_active then
    session:clear_pending_action()
    return { wait = true }
  end
  return {
    next_state = "end_turn",
    next_args = args,
  }
end

function await.inter_turn(session, args)
  assert(session ~= nil and session.game ~= nil, "missing await session")
  local game = session.game
  session:mark_phase("inter_turn_wait")
  if game.turn.inter_turn_wait_active then
    session:clear_pending_action()
    return { wait = true }
  end
  local turn_mgr = session.turn_mgr or session
  assert(type(turn_mgr.next_player) == "function", "missing turn_mgr.next_player")
  turn_mgr:next_player()
  return {
    next_state = "start",
    next_args = args,
  }
end

function await.seconds(session, sec, opts)
  assert(session ~= nil, "missing await session")
  local wait_sec = sec or 0
  if wait_sec <= 0 then
    return { done = true }
  end
  opts = opts or {}
  local key = opts.key or "__default__"
  local now_fn = opts.now_fn
  if type(now_fn) ~= "function" then
    -- Sandbox runtime may not provide os.clock; no timer source means skip waiting.
    return { done = true }
  end
  local ok, now_or_err = pcall(now_fn)
  if not ok or not number_utils.is_numeric(now_or_err) then
    return { done = true }
  end
  local now = now_or_err
  local started = session._seconds_wait[key]
  if started == nil then
    session._seconds_wait[key] = now
    return { wait = true }
  end
  if (now - started) < wait_sec then
    return { wait = true }
  end
  session._seconds_wait[key] = nil
  return { done = true }
end

return await
