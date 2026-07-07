local wait_callbacks = require("src.turn.waits.callback_registry")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local shared = require("src.turn.waits.await_shared")

local _WAIT = shared.WAIT
local _unpack_next = shared.unpack_next
local _mark_dirty = shared.mark_dirty

local callback_keys = wait_callbacks.callback_keys
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

local action_anim = {}

action_anim.action_anim = _action_anim
action_anim._coalesce_head = _coalesce_head

return action_anim

--[[ mutate4lua-manifest
version=2
projectHash=23e2c9266dcb0e39
scope.0.id=chunk:src/turn/waits/await_action_anim.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=164
scope.0.semanticHash=dacbed995ae62d70
scope.0.lastMutatedAt=2026-07-07T02:12:03Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=14
scope.0.lastMutationKilled=14
scope.1.id=function:_resolve_action_anim_wait:14
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=21
scope.1.semanticHash=c84698c73de76f40
scope.1.lastMutatedAt=2026-07-07T02:12:03Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=survived
scope.1.lastMutationSites=3
scope.1.lastMutationKilled=2
scope.2.id=function:_resolve_action_anim_idle:23
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=36
scope.2.semanticHash=11d5a8025519523f
scope.2.lastMutatedAt=2026-07-07T02:12:03Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=3
scope.2.lastMutationKilled=3
scope.3.id=function:_is_anim_timed_out:38
scope.3.kind=function
scope.3.startLine=38
scope.3.endLine=45
scope.3.semanticHash=94289ebfb4a01dfa
scope.3.lastMutatedAt=2026-07-07T02:12:03Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=8
scope.3.lastMutationKilled=8
scope.4.id=function:_is_matching_done_action:47
scope.4.kind=function
scope.4.startLine=47
scope.4.endLine=55
scope.4.semanticHash=13df182f768364d7
scope.4.lastMutatedAt=2026-07-07T02:12:03Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=9
scope.4.lastMutationKilled=9
scope.5.id=function:_complete_action_anim:57
scope.5.kind=function
scope.5.startLine=57
scope.5.endLine=69
scope.5.semanticHash=946e8c4f384c6009
scope.5.lastMutatedAt=2026-07-07T02:12:03Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=4
scope.5.lastMutationKilled=4
scope.6.id=function:_is_cash_receive_anim:71
scope.6.kind=function
scope.6.startLine=71
scope.6.endLine=73
scope.6.semanticHash=3463c757bed93e7b
scope.6.lastMutatedAt=2026-07-07T02:12:03Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=3
scope.6.lastMutationKilled=3
scope.7.id=function:_coalesce_head:98
scope.7.kind=function
scope.7.startLine=98
scope.7.endLine=113
scope.7.semanticHash=0a0ef2e0fbaaf80d
scope.7.lastMutatedAt=2026-07-07T02:12:03Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=9
scope.7.lastMutationKilled=9
scope.8.id=function:anonymous@115:115
scope.8.kind=function
scope.8.startLine=115
scope.8.endLine=127
scope.8.semanticHash=d662cc211af1c122
scope.8.lastMutatedAt=2026-07-07T02:12:03Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=11
scope.8.lastMutationKilled=11
scope.9.id=function:_action_anim:129
scope.9.kind=function
scope.9.startLine=129
scope.9.endLine=156
scope.9.semanticHash=1b62e44b7be5724e
scope.9.lastMutatedAt=2026-07-07T02:12:03Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=18
scope.9.lastMutationKilled=18
]]
