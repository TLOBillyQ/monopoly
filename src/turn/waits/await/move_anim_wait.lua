local debug_helpers = require("src.turn.waits.await.debug")

local M = {}

local function _resolve_wait_anim(game, opts)
  opts = opts or {}
  local anim_key = opts.anim_key or "move_anim"
  return anim_key, game and game.turn and game.turn[anim_key] or nil
end

local function _resolve_pending_action(session)
  if not (session and session.peek_pending_action) then
    return nil
  end
  return session:peek_pending_action()
end

local function _build_move_anim_wait_details(game, anim, action)
  return {
    phase = game and game.turn and game.turn.phase or "nil",
    anim_seq = anim and anim.seq or "nil",
    action_type = action and action.type or "nil",
    action_seq = action and action.seq or "nil",
  }
end

local function _log_move_anim_wait(session, opts)
  local game = session and session.game or nil
  local _, anim = _resolve_wait_anim(game, opts)
  local action = _resolve_pending_action(session)
  local details = _build_move_anim_wait_details(game, anim, action)
  debug_helpers.log(
    "await_move_anim",
    "phase=" .. tostring(details.phase),
    "anim_seq=" .. tostring(details.anim_seq),
    "pending_action_type=" .. tostring(details.action_type),
    "pending_action_seq=" .. tostring(details.action_seq)
  )
end

function M.resolve_wait_anim_opts(opts)
  opts = opts or {}
  return {
    state_name = opts.state_name or "wait_move_anim",
    anim_key = opts.anim_key or "move_anim",
    done_action_type = opts.done_action_type or "move_anim_done",
  }
end

function M.log_move_anim_wait(session, opts)
  _log_move_anim_wait(session, opts)
end

return M
