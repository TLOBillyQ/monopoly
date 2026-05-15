local wait_callbacks = require("src.turn.waits.callback_registry")
local timing = require("src.config.gameplay.timing")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local landing_visual_hold = require("src.state.visual_hold")
local auto_play_port = require("src.rules.ports.auto_play")
local tip_queue = require("src.foundation.tips")
local shared = require("src.turn.waits.await.shared")

local M = {}

local callback_keys = wait_callbacks.callback_keys
local wait_keys = wait_callbacks.wait_keys

local _next = shared.unpack_next
local _mark_dirty = shared.mark_dirty
local _WAIT = shared.WAIT

function M.landing_visual(session, args)
  assert(session ~= nil and session.game ~= nil, "missing await session")
  local game = session.game
  session:mark_phase("wait_landing_visual")
  assert(game.turn ~= nil, "missing game.turn")

  if wait_callbacks.peek(game, callback_keys.after_landing_visual) == nil then
    wait_callbacks.register(game, callback_keys.after_landing_visual, function()
      return _next(args)
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
    next_state, next_args = _next(args)
  end
  return {
    next_state = next_state,
    next_args = next_args,
  }
end

function M.detained(session, args)
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

function M.inter_turn(session, args)
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

function M.action(session, args)
  assert(session ~= nil and session.game ~= nil, "missing await session")
  local game = session.game
  session:mark_phase("wait_action")
  local player = game:current_player()
  if auto_play_port.is_auto_player(game, player) then
    return {
      next_state = args and args.next_state or "roll",
      next_args = args and args.next_args or { player = player },
    }
  end
  local peeked = session:peek_pending_action()
  if peeked and (peeked.type == "choice_select"
              or peeked.type == "choice_cancel"
              or peeked.type == "choice_force_skip") then
    -- 不消费；由 wait_choice.M.choice 的 take_pending_action 取走处理
    return {
      next_state = args and args.next_state or "roll",
      next_args = args and args.next_args or { player = player },
    }
  end
  local action = session:take_pending_action()
  if action then
    return {
      next_state = args and args.next_state or "roll",
      next_args = args and args.next_args or { player = player },
    }
  end
  return _WAIT
end

return M
