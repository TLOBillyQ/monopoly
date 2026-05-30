local dirty_tracker = require("src.state.dirty_tracker")
local wait_callbacks = require("src.turn.waits.callback_registry")
local timing = require("src.config.gameplay.timing")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local landing_visual_hold = require("src.state.visual_hold")
local auto_play_port = require("src.rules.ports.auto_play")
local tip_queue = require("src.foundation.tips")
local turn_decision = require("src.turn.waits.decision")
local validator = require("src.turn.actions.validator")
local number_utils = require("src.foundation.number")
local chain_args = require("src.foundation.chain_args")
local move_anim_debug = require("src.foundation.move_anim_debug")

local _WAIT = { wait = true }
local _DONE = { done = true }

local function _unpack_next(args)
  args = args or {}
  return args.next_state, args.next_args
end

local _mark_dirty = dirty_tracker.mark_turn

local function _session_game(session)
  return session and session.game or nil
end

local function _turn_from_game(game)
  return game and game.turn or nil
end

local function _turn_anim(turn, anim_key)
  return turn and turn[anim_key] or nil
end

local function _peek_pending_action(session)
  return session and session.peek_pending_action and session:peek_pending_action() or nil
end

local function _log_move_anim_wait(session, opts)
  local game = _session_game(session)
  opts = opts or {}
  local anim_key = opts.anim_key or "move_anim"
  local turn = _turn_from_game(game)
  local anim = _turn_anim(turn, anim_key)
  local action = _peek_pending_action(session)
  move_anim_debug.log(
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

local function _is_cash_receive_anim(anim)
  return anim and anim.kind == "cash_receive"
end

local function _cash_receive_merge_end(queue)
  for i = 2, #queue do
    if not _is_cash_receive_anim(queue[i]) then
      return i - 1
    end
  end
  return #queue
end

local function _cash_receive_total(queue, merge_end)
  local total_amount = queue[1].amount or 0
  for i = 2, merge_end do
    total_amount = total_amount + (queue[i].amount or 0)
  end
  return total_amount
end

local function _remove_coalesced_actions(queue, merge_end)
  for _ = 2, merge_end do
    table.remove(queue, 2)
  end
end

local function _coalesce_head(queue)
  if #queue < 2 then
    return
  end
  local head = queue[1]
  if not _is_cash_receive_anim(head) then
    return
  end
  local merge_end = _cash_receive_merge_end(queue)
  if merge_end <= 1 then
    return
  end
  head.amount = _cash_receive_total(queue, merge_end)
  head.coalesced_count = merge_end
  _remove_coalesced_actions(queue, merge_end)
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

local _resolve_choice_action
local _validate_choice_action
local _wait_for_choice_action_anim

local _decide_opts = { elapsed_seconds = 0 }

local function _resolve_after_action_anim(args, res)
  return chain_args.resolve_after_action_anim(args, res, "move_followup")
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
  if move_anim_debug.enabled() then
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

--[[ mutate4lua-manifest
version=2
projectHash=47b8eebf2a23aee6
scope.0.id=chunk:src/turn/waits/await.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=536
scope.0.semanticHash=2232d960cef43379
scope.1.id=function:_unpack_next:17
scope.1.kind=function
scope.1.startLine=17
scope.1.endLine=20
scope.1.semanticHash=f7f4e2934b9cf33f
scope.2.id=function:_session_game:24
scope.2.kind=function
scope.2.startLine=24
scope.2.endLine=26
scope.2.semanticHash=51171dcfb18b4304
scope.3.id=function:_turn_from_game:28
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=30
scope.3.semanticHash=4ed39ac00ceb02a5
scope.4.id=function:_turn_anim:32
scope.4.kind=function
scope.4.startLine=32
scope.4.endLine=34
scope.4.semanticHash=b901f0989aca19cd
scope.5.id=function:_peek_pending_action:36
scope.5.kind=function
scope.5.startLine=36
scope.5.endLine=38
scope.5.semanticHash=d663a0c2e1f97b09
scope.6.id=function:_log_move_anim_wait:40
scope.6.kind=function
scope.6.startLine=40
scope.6.endLine=54
scope.6.semanticHash=a0d890930b4efdf9
scope.7.id=function:_resolve_wait_anim_opts:62
scope.7.kind=function
scope.7.startLine=62
scope.7.endLine=67
scope.7.semanticHash=819b97ba44b3d2c6
scope.8.id=function:_resolve_action_anim_wait:75
scope.8.kind=function
scope.8.startLine=75
scope.8.endLine=82
scope.8.semanticHash=c84698c73de76f40
scope.9.id=function:_resolve_action_anim_idle:84
scope.9.kind=function
scope.9.startLine=84
scope.9.endLine=97
scope.9.semanticHash=11d5a8025519523f
scope.10.id=function:_is_anim_timed_out:99
scope.10.kind=function
scope.10.startLine=99
scope.10.endLine=106
scope.10.semanticHash=94289ebfb4a01dfa
scope.11.id=function:_is_matching_done_action:108
scope.11.kind=function
scope.11.startLine=108
scope.11.endLine=116
scope.11.semanticHash=13df182f768364d7
scope.12.id=function:_complete_action_anim:118
scope.12.kind=function
scope.12.startLine=118
scope.12.endLine=130
scope.12.semanticHash=946e8c4f384c6009
scope.13.id=function:_is_cash_receive_anim:132
scope.13.kind=function
scope.13.startLine=132
scope.13.endLine=134
scope.13.semanticHash=3463c757bed93e7b
scope.14.id=function:_coalesce_head:159
scope.14.kind=function
scope.14.startLine=159
scope.14.endLine=174
scope.14.semanticHash=0a0ef2e0fbaaf80d
scope.15.id=function:anonymous@176:176
scope.15.kind=function
scope.15.startLine=176
scope.15.endLine=188
scope.15.semanticHash=d662cc211af1c122
scope.16.id=function:_action_anim:190
scope.16.kind=function
scope.16.startLine=190
scope.16.endLine=217
scope.16.semanticHash=1b62e44b7be5724e
scope.17.id=function:anonymous@226:226
scope.17.kind=function
scope.17.startLine=226
scope.17.endLine=228
scope.17.semanticHash=3e650647ce663b00
scope.18.id=function:anonymous@236:236
scope.18.kind=function
scope.18.startLine=236
scope.18.endLine=241
scope.18.semanticHash=39dc2487752eb406
scope.19.id=function:_landing_visual:219
scope.19.kind=function
scope.19.startLine=219
scope.19.endLine=262
scope.19.semanticHash=2f4d9a36da8c7ff2
scope.20.id=function:_detained:264
scope.20.kind=function
scope.20.startLine=264
scope.20.endLine=276
scope.20.semanticHash=95f7ed91505d11d1
scope.21.id=function:_inter_turn:278
scope.21.kind=function
scope.21.startLine=278
scope.21.endLine=297
scope.21.semanticHash=b599a71619d07bf3
scope.22.id=function:_is_choice_action:301
scope.22.kind=function
scope.22.startLine=301
scope.22.endLine=304
scope.22.semanticHash=d38acae24912679b
scope.23.id=function:_build_action_next:306
scope.23.kind=function
scope.23.startLine=306
scope.23.endLine=311
scope.23.semanticHash=c4ed43e077237b77
scope.24.id=function:_action:313
scope.24.kind=function
scope.24.startLine=313
scope.24.endLine=331
scope.24.semanticHash=48821194d0b98099
scope.25.id=function:_resolve_after_action_anim:339
scope.25.kind=function
scope.25.startLine=339
scope.25.endLine=341
scope.25.semanticHash=ea3de58a8f0adf16
scope.26.id=function:_clear_choice_wait:343
scope.26.kind=function
scope.26.startLine=343
scope.26.endLine=351
scope.26.semanticHash=c57e352f42405a93
scope.27.id=function:_resolve_choice_result:353
scope.27.kind=function
scope.27.startLine=353
scope.27.endLine=369
scope.27.semanticHash=60048a98e28e4de0
scope.28.id=function:_finish_choice_wait:371
scope.28.kind=function
scope.28.startLine=371
scope.28.endLine=384
scope.28.semanticHash=f5e05b6ad22b4ccb
scope.29.id=function:anonymous@386:386
scope.29.kind=function
scope.29.startLine=386
scope.29.endLine=393
scope.29.semanticHash=8babb436e8bb8c64
scope.30.id=function:anonymous@395:395
scope.30.kind=function
scope.30.startLine=395
scope.30.endLine=403
scope.30.semanticHash=49ee766c1a96e952
scope.31.id=function:anonymous@405:405
scope.31.kind=function
scope.31.startLine=405
scope.31.endLine=417
scope.31.semanticHash=1f9e120a87fb5b5b
scope.32.id=function:_choice:419
scope.32.kind=function
scope.32.startLine=419
scope.32.endLine=436
scope.32.semanticHash=cae4baddcb0856a5
scope.33.id=function:_resolve_seconds_wait:438
scope.33.kind=function
scope.33.startLine=438
scope.33.endLine=445
scope.33.semanticHash=d78bb7367d63ec99
scope.34.id=function:_resolve_seconds_now:447
scope.34.kind=function
scope.34.startLine=447
scope.34.endLine=456
scope.34.semanticHash=540a3c244aefb314
scope.35.id=function:_resolve_seconds_key:458
scope.35.kind=function
scope.35.startLine=458
scope.35.endLine=463
scope.35.semanticHash=7eb2f4bb67e93ccc
scope.36.id=function:_await_seconds_step:465
scope.36.kind=function
scope.36.startLine=465
scope.36.endLine=480
scope.36.semanticHash=cb99b31c3eabbb0f
scope.37.id=function:_seconds:482
scope.37.kind=function
scope.37.startLine=482
scope.37.endLine=489
scope.37.semanticHash=dce1f2278566bd2e
scope.38.id=function:_await_anim_done:491
scope.38.kind=function
scope.38.startLine=491
scope.38.endLine=511
scope.38.semanticHash=4fe005492aff8495
scope.39.id=function:await.move_anim:517
scope.39.kind=function
scope.39.startLine=517
scope.39.endLine=522
scope.39.semanticHash=f3ed5e91a0d16070
]]
