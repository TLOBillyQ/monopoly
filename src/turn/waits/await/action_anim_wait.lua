local wait_callbacks = require("src.turn.waits.callback_registry")
local runtime_ports = require("src.core.ports.runtime_ports")

local M = {}

local callback_keys = wait_callbacks.callback_keys
local anim_done_timeout_seconds = 10.0

local _next_action_anim

local function _next(args)
  args = args or {}
  return args.next_state, args.next_args
end

local function _mark_dirty(game)
  if game and game.dirty then
    game.dirty.turn = true
    game.dirty.any = true
  end
end

local function _resolve_action_anim_wait(game)
  local anim = game.turn.action_anim
  if anim then
    return anim, false
  end
  local next_anim = _next_action_anim(game)
  return next_anim, next_anim ~= nil
end

local function _resolve_action_anim_idle(session, args, game, anim, queued_next_anim)
  if anim ~= nil then
    return nil
  end
  if queued_next_anim then
    return { wait = true }
  end
  session:clear_pending_action()
  local next_state, next_args = _next(args)
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
    return { wait = true }
  end
  session:clear_pending_action()
  local next_state, next_args = _next(args)
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

function M.action_anim(session, args)
  assert(session ~= nil and session.game ~= nil, "missing await session")
  local game = session.game
  session:mark_phase("wait_action_anim")
  local anim, queued_next_anim = _resolve_action_anim_wait(game)
  local idle_res = _resolve_action_anim_idle(session, args, game, anim, queued_next_anim)
  if idle_res ~= nil then
    return idle_res
  end

  local action = session:take_pending_action()
  if _is_anim_timed_out(anim) then
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
  if not _is_matching_done_action(action, anim, "action_anim_done") then
    return { wait = true }
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

return M
