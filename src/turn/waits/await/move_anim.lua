local debug_helpers = require("src.turn.waits.await.debug")

local M = {}

local function _log_move_anim_wait(session, opts)
  local game = session and session.game or nil
  opts = opts or {}
  local anim_key = opts.anim_key or "move_anim"
  local anim = game and game.turn and game.turn[anim_key] or nil
  local action = session and session.peek_pending_action and session:peek_pending_action() or nil
  local turn = game and game.turn or nil
  debug_helpers.log(
    "await_move_anim",
    "phase=" .. tostring(turn and turn.phase or "nil"),
    "anim_seq=" .. tostring(anim and anim.seq or "nil"),
    "pending_action_type=" .. tostring(action and action.type or "nil"),
    "pending_action_seq=" .. tostring(action and action.seq or "nil")
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

M.log_move_anim_wait = _log_move_anim_wait

return M
