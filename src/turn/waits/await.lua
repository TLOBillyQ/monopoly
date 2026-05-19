local dirty_tracker = require("src.state.dirty_tracker")
local logger = require("src.foundation.log")
local debug_flags = require("src.config.gameplay.debug_flags")
local wait_callbacks = require("src.turn.waits.callback_registry")
local timing = require("src.config.gameplay.timing")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local landing_visual_hold = require("src.state.visual_hold")
local auto_play_port = require("src.rules.ports.auto_play")
local tip_queue = require("src.foundation.tips")
local turn_decision = require("src.turn.waits.decision")
local validator = require("src.turn.actions.validator")
local number_utils = require("src.foundation.number")

local _WAIT = { wait = true }
local _DONE = { done = true }

local function _unpack_next(args)
  args = args or {}
  return args.next_state, args.next_args
end

local function _mark_dirty(game)
  if game and game.dirty then
    dirty_tracker.mark(game.dirty, "turn")
  end
end

local function _should_log()
  return logger.is_anim_debug_enabled() or debug_flags.move_anim_debug_log_enabled == true
end

local function _debug_log(...)
  if not _should_log() then
    return
  end
  logger.info_unlimited("[MoveAnim]", ...)
end

local function _log_move_anim_wait(session, opts)
  local game = session and session.game or nil
  opts = opts or {}
  local anim_key = opts.anim_key or "move_anim"
  local anim = game and game.turn and game.turn[anim_key] or nil
  local action = session and session.peek_pending_action and session:peek_pending_action() or nil
  local turn = game and game.turn or nil
  _debug_log(
    "await_move_anim",
    "phase=" .. tostring(turn and turn.phase or "nil"),
    "anim_seq=" .. tostring(anim and anim.seq or "nil"),
    "pending_action_type=" .. tostring(action and action.type or "nil"),
    "pending_action_seq=" .. tostring(action and action.seq or "nil")
  )
end

local _cached_anim_opts = {
  state_name = nil,
  anim_key = nil,
  done_action_type = nil,
}

local function _resolve_wait_anim_opts(opts)
  _cached_anim_opts.state_name = opts and opts.state_name or "wait_move_anim"
  _cached_anim_opts.anim_key = opts and opts.anim_key or "move_anim"
  _cached_anim_opts.done_action_type = opts and opts.done_action_type or "move_anim_done"
  return _cached_anim_opts
end

local callback_keys = wait_callbacks.callback_keys
local wait_keys = wait_callbacks.wait_keys
local anim_done_timeout_seconds = 10.0

local _next_action_anim

local function _resolve_action_anim_wait(game)
  local anim = game.turn.action_anim
  if anim then
    return anim, false
  end
  local next_anim = _next_action_anim(game)
  return next_anim, next_anim ~= nil
end

local function _resolve_action_anim_idle(session, args, _, anim, queued_next_anim)
  if anim ~= nil then
    return nil
  end
  if queued_next_anim then
    return _WAIT
  end
  session:clear_pending_action()
  local next_state, next_args = _unpack_next(args)
  return {
    next_state = next_state,
    next_args = next_args,
  }
end

local function _is_anim_timed_out(anim)
  if not anim or not anim.started_at then
    return false
  end
  local elapsed = runtime_ports.wall_diff_seconds(runtime_ports.wall_now_seconds(), anim.started_at)
  local timeout = (anim.duration or 2.0) + anim_done_timeout_seconds
  return elapsed >= timeout
end

local function _is_matching_done_action(action, anim, action_type)
  if not action or action.type ~= action_type then
    return false
  end
  if action.seq and anim.seq and action.seq ~= anim.seq then
    return false
  end
  return true
end

local function _complete_action_anim(session, args, game)
  game.turn.action_anim = nil
  _mark_dirty(game)
  if _next_action_anim(game) then
    return _WAIT
  end
  session:clear_pending_action()
  local next_state, next_args = _unpack_next(args)
  return {
    next_state = next_state,
    next_args = next_args,
  }
end

local function _coalesce_head(queue)
  if #queue < 2 then
    return
  end
  local head = queue[1]
  if head.kind ~= "cash_receive" then
    return
  end
  local merge_end = 1
  for i = 2, #queue do
    if queue[i].kind ~= "cash_receive" then
      break
    end
    merge_end = i
  end
  if merge_end <= 1 then
    return
  end
  local total_amount = head.amount or 0
  for i = 2, merge_end do
    total_amount = total_amount + (queue[i].amount or 0)
  end
  head.amount = total_amount
  head.coalesced_count = merge_end
  for _ = 2, merge_end do
    table.remove(queue, 2)
  end
end

_next_action_anim = function(game)
  assert(game ~= nil and game.turn ~= nil, "missing game.turn")
  local queue = game.turn.action_anim_queue
  if type(queue) ~= "table" or #queue == 0 then
    return nil
  end
  _coalesce_head(queue)
  local anim = table.remove(queue, 1)
  anim.started_at = runtime_ports.wall_now_seconds()
  game.turn.action_anim = anim
  _mark_dirty(game)
  return anim
end

local function _action_anim(session, args)
  assert(session ~= nil and session.game ~= nil, "missing await session")
  local game = session.game
  session:mark_phase("wait_action_anim")
  local anim, queued_next_anim = _resolve_action_anim_wait(game)
  local idle_res = _resolve_action_anim_idle(session, args, game, anim, queued_next_anim)
  if idle_res ~= nil then
    return idle_res
  end

  local action = session:take_pending_action()
  if not _is_anim_timed_out(anim) and not _is_matching_done_action(action, anim, "action_anim_done") then
    return _WAIT
  end
  local completed = _complete_action_anim(session, args, game)
  if completed and completed.wait == true then
    return completed
  end
  local continuation = wait_callbacks.take(game, callback_keys.after_action_anim)
  if continuation == nil then
    return completed
  end
  local next_state, next_args = continuation()
  return {
    next_state = next_state,
    next_args = next_args,
  }
end

local function _landing_visual(session, args)
  assert(session ~= nil and session.game ~= nil, "missing await session")
  local game = session.game
  session:mark_phase("wait_landing_visual")
  assert(game.turn ~= nil, "missing game.turn")

  if wait_callbacks.peek(game, callback_keys.after_landing_visual) == nil then
    wait_callbacks.register(game, callback_keys.after_landing_visual, function()
      return _unpack_next(args)
    end)
  end

  local pending_seq = wait_callbacks.pending_wait_seq(game, wait_keys.landing_visual)
  if pending_seq == nil then
    local seq = wait_callbacks.begin_wait(game, wait_keys.landing_visual)
    _mark_dirty(game)
    local delay = timing.landing_visual_hold_seconds or 0
    runtime_ports.schedule(delay, function()
      if wait_callbacks.pending_wait_seq(game, wait_keys.landing_visual) == seq then
        wait_callbacks.mark_wait_ready(game, wait_keys.landing_visual, seq)
        _mark_dirty(game)
      end
    end)
    return _WAIT
  end

  if not wait_callbacks.is_wait_ready(game, wait_keys.landing_visual) then
    return _WAIT
  end

  wait_callbacks.finish_wait(game, wait_keys.landing_visual, pending_seq)
  landing_visual_hold.mark_release_pending(game)
  local continuation = wait_callbacks.take(game, callback_keys.after_landing_visual)
  local next_state, next_args
  if continuation ~= nil then
    next_state, next_args = continuation()
  else
    next_state, next_args = _unpack_next(args)
  end
  return {
    next_state = next_state,
    next_args = next_args,
  }
end

local function _detained(session, args)
  assert(session ~= nil and session.game ~= nil, "missing await session")
  local game = session.game
  session:mark_phase("detained_wait")
  if game.turn.detained_wait_active then
    session:clear_pending_action()
    return _WAIT
  end
  return {
    next_state = "end_turn",
    next_args = args,
  }
end

local function _inter_turn(session, args)
  assert(session ~= nil and session.game ~= nil, "missing await session")
  local game = session.game
  session:mark_phase("inter_turn_wait")
  if game.turn.inter_turn_wait_active then
    session:clear_pending_action()
    return _WAIT
  end
  if tip_queue.has_blocking_pending("inter_turn") then
    session:clear_pending_action()
    return _WAIT
  end
  local turn_mgr = session.turn_mgr or session
  assert(type(turn_mgr.next_player) == "function", "missing turn_mgr.next_player")
  turn_mgr:next_player()
  return {
    next_state = "start",
    next_args = args,
  }
end

local _CHOICE_ACTION_TYPES = { choice_select = true, choice_cancel = true, choice_force_skip = true }

local function _is_choice_action(peeked)
  if not peeked then return false end
  return _CHOICE_ACTION_TYPES[peeked.type] == true
end

local function _build_action_next(args, player)
  return {
    next_state = args and args.next_state or "roll",
    next_args = args and args.next_args or { player = player },
  }
end

local function _action(session, args)
  assert(session, "missing await session")
  assert(session.game, "missing await session.game")
  local game = session.game
  session:mark_phase("wait_action")
  local player = game:current_player()
  if auto_play_port.is_auto_player(game, player) then
    return _build_action_next(args, player)
  end
  local peeked = session:peek_pending_action()
  if _is_choice_action(peeked) then
    return _build_action_next(args, player)
  end
  local action = session:take_pending_action()
  if action then
    return _build_action_next(args, player)
  end
  return _WAIT
end

local _resolve_after_action_anim_state
local _resolve_choice_action
local _validate_choice_action
local _wait_for_choice_action_anim

local _decide_opts = { elapsed_seconds = 0 }

local function _resolve_after_action_anim(args, res)
  local default_next_state, default_next_args = _unpack_next(args)
  local next_state, next_args = default_next_state, default_next_args
  local after_action_anim = type(res) == "table" and res.after_action_anim or nil
  if type(after_action_anim) ~= "table" then
    return next_state, next_args
  end
  return _resolve_after_action_anim_state(
    after_action_anim.next_state or next_state,
    after_action_anim.next_args or next_args,
    default_next_state,
    default_next_args
  )
end

_resolve_after_action_anim_state = function(next_state, next_args, default_next_state, default_next_args)
  if next_state ~= "move_followup" or type(next_args) ~= "table" then
    return next_state, next_args
  end
  next_args.next_state = next_args.next_state or default_next_state
  next_args.next_args = next_args.next_args or default_next_args
  return next_state, next_args
end

local function _clear_choice_wait(session, args)
  session.choice_elapsed_seconds = 0
  session:clear_pending_action()
  local next_state, next_args = _unpack_next(args)
  return {
    next_state = next_state,
    next_args = next_args,
  }
end

local function _resolve_choice_result(game, choice, session)
  local action = _resolve_choice_action(choice, session, game)
  if action == nil then
    return nil, false
  end
  if not _validate_choice_action(action, choice) then
    return nil, false
  end
  if action.type == "choice_force_skip" then
    if game and game.turn then
      game.turn.pending_choice = nil
      _mark_dirty(game)
    end
    return {}, true
  end
  return turn_decision.resolve_choice(game, choice, action), true
end

local function _finish_choice_wait(session, args, game, res)
  if res and res.stay then
    return _WAIT
  end
  session.choice_elapsed_seconds = 0
  local next_state, next_args = _resolve_after_action_anim(args, res)
  if game.turn.action_anim then
    return _wait_for_choice_action_anim(game, next_state, next_args)
  end
  return {
    next_state = next_state,
    next_args = next_args,
  }
end

_resolve_choice_action = function(choice, session, game)
  if game and game.turn and game.turn._choice_force_skip_pending then
    game.turn._choice_force_skip_pending = nil
    return { type = "choice_force_skip", choice_id = choice and choice.id }
  end
  _decide_opts.elapsed_seconds = session.choice_elapsed_seconds or 0
  return turn_decision.decide_choice_action(game, choice, session:take_pending_action(), _decide_opts)
end

_validate_choice_action = function(action, choice)
  if action.type == "choice_force_skip" then
    return true
  end
  if action.type ~= "choice_select" and action.type ~= "choice_cancel" then
    return true
  end
  return validator.validate_choice_id(action, choice)
end

_wait_for_choice_action_anim = function(game, next_state, next_args)
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

local function _choice(session, args)
  assert(session ~= nil and session.game ~= nil, "missing await session")
  local game = session.game
  session:mark_phase("wait_choice")
  local choice = game.turn.pending_choice
  if not choice then
    if game.turn._choice_force_skip_pending then
      game.turn._choice_force_skip_pending = nil
    end
    return _clear_choice_wait(session, args)
  end

  local res, resolved = _resolve_choice_result(game, choice, session)
  if not resolved then
    return _WAIT
  end
  return _finish_choice_wait(session, args, game, res)
end

local function _resolve_seconds_wait(key, session, now)
  local started = session._seconds_wait[key]
  if started == nil then
    session._seconds_wait[key] = now
    return nil, true
  end
  return started, false
end

local function _resolve_seconds_now(now_fn)
  if type(now_fn) ~= "function" then
    return nil
  end
  local ok, now_or_err = pcall(now_fn)
  if not ok or not number_utils.is_numeric(now_or_err) then
    return nil
  end
  return now_or_err
end

local function _resolve_seconds_key(opts)
  if type(opts) ~= "table" or opts.key == nil then
    return "__default__"
  end
  return opts.key
end

local function _await_seconds_step(session, wait_sec, opts)
  local key = _resolve_seconds_key(opts)
  local now = _resolve_seconds_now(opts and opts.now_fn)
  if now == nil then
    return _DONE
  end
  local started, started_now = _resolve_seconds_wait(key, session, now)
  if started_now then
    return _WAIT
  end
  if (now - started) < wait_sec then
    return _WAIT
  end
  session._seconds_wait[key] = nil
  return _DONE
end

local function _seconds(session, sec, opts)
  assert(session ~= nil, "missing await session")
  local wait_sec = sec or 0
  if wait_sec <= 0 then
    return _DONE
  end
  return _await_seconds_step(session, wait_sec, opts)
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
    return _WAIT
  end
  if action.seq and anim.seq and action.seq ~= anim.seq then
    return _WAIT
  end
  game.turn[opts.anim_key] = nil
  _mark_dirty(game)
  local next_state, next_args = _unpack_next(args)
  return { next_state = next_state, next_args = next_args }
end

local await = {}

await.choice = _choice

function await.move_anim(session, args, opts)
  if _should_log() then
    _log_move_anim_wait(session, opts)
  end
  return _await_anim_done(session, args, _resolve_wait_anim_opts(opts))
end

await.action_anim = _action_anim
await.landing_visual = _landing_visual
await.detained = _detained
await.inter_turn = _inter_turn
await.seconds = _seconds
await.action = _action

await._M_test = {
  _coalesce_head = _coalesce_head,
}

return await
