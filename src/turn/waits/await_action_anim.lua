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
    -- 第二返回值只在 anim 缺失时被消费(_resolve_action_anim_idle 先判
    -- anim ~= nil),anim 在场时恒不被读——false 字面值是死位(等价变异体)。
    return anim
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

local function _seq_mismatch(action, anim)
  return action.seq and anim.seq and action.seq ~= anim.seq
end

local function _is_matching_done_action(action, anim, action_type)
  if not action or action.type ~= action_type then
    return false
  end
  if _seq_mismatch(action, anim) then
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
  -- game 与 game.turn 恒非 nil(两个调用方都先读写 game.turn 才到这里),
  -- 曾经的入口断言恒不触发——等价变异体,按 #257 三分类删冗余。
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

-- 动画收尾后若挂了 after_action_anim 回调，用回调结果接续状态机。
local function _resume_after_action_anim(game, completed)
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

local function _should_wait_anim(action, anim)
  return not _is_anim_timed_out(anim) and not _is_matching_done_action(action, anim, "action_anim_done")
end

local function _completed_wait(completed)
  return completed ~= nil and completed.wait == true
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
  if _should_wait_anim(action, anim) then
    return _WAIT
  end
  local completed = _complete_action_anim(session, args, game)
  if _completed_wait(completed) then
    return completed
  end
  return _resume_after_action_anim(game, completed)
end

local action_anim = {}

action_anim.action_anim = _action_anim
action_anim._coalesce_head = _coalesce_head

return action_anim

--[[ mutate4lua-manifest
version=4
projectHash=6167bdcb4db30f24
scope.0.id=chunk:src/turn/waits/await_action_anim.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=184
scope.0.semanticHash=2ecbb29a0457bb35
scope.1.id=function:_resolve_action_anim_wait
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=23
scope.1.semanticHash=d2e04cb842fcb9d8
scope.2.id=function:_resolve_action_anim_idle
scope.2.kind=function
scope.2.startLine=25
scope.2.endLine=38
scope.2.semanticHash=95bf83f032b0cd53
scope.3.id=function:_is_anim_timed_out
scope.3.kind=function
scope.3.startLine=40
scope.3.endLine=47
scope.3.semanticHash=6865e0285aa5d047
scope.4.id=function:_seq_mismatch
scope.4.kind=function
scope.4.startLine=49
scope.4.endLine=51
scope.4.semanticHash=74fb2c7858e26475
scope.5.id=function:_is_matching_done_action
scope.5.kind=function
scope.5.startLine=53
scope.5.endLine=61
scope.5.semanticHash=9abcaac6a4bc80fb
scope.6.id=function:_complete_action_anim
scope.6.kind=function
scope.6.startLine=63
scope.6.endLine=75
scope.6.semanticHash=49d347d4ede8ccd9
scope.7.id=function:_is_cash_receive_anim
scope.7.kind=function
scope.7.startLine=77
scope.7.endLine=79
scope.7.semanticHash=0d43a473e032cea8
scope.8.id=function:_cash_receive_merge_end
scope.8.kind=function
scope.8.startLine=81
scope.8.endLine=88
scope.8.semanticHash=6fe9c9b4f720e7a3
scope.9.id=function:_cash_receive_total
scope.9.kind=function
scope.9.startLine=90
scope.9.endLine=96
scope.9.semanticHash=b47da88be872fffd
scope.10.id=function:_remove_coalesced_actions
scope.10.kind=function
scope.10.startLine=98
scope.10.endLine=102
scope.10.semanticHash=689bb9343fe66d26
scope.11.id=function:_coalesce_head
scope.11.kind=function
scope.11.startLine=104
scope.11.endLine=119
scope.11.semanticHash=46b81ae45de6f969
scope.12.id=function:_next_action_anim
scope.12.kind=function
scope.12.startLine=121
scope.12.endLine=134
scope.12.semanticHash=5a045ef6fd0300f8
scope.13.id=function:_resume_after_action_anim
scope.13.kind=function
scope.13.startLine=137
scope.13.endLine=147
scope.13.semanticHash=9244379180bc5ab5
scope.14.id=function:_should_wait_anim
scope.14.kind=function
scope.14.startLine=149
scope.14.endLine=151
scope.14.semanticHash=2939423de433dad8
scope.15.id=function:_completed_wait
scope.15.kind=function
scope.15.startLine=153
scope.15.endLine=155
scope.15.semanticHash=be8994585243633b
scope.16.id=function:_action_anim
scope.16.kind=function
scope.16.startLine=157
scope.16.endLine=176
scope.16.semanticHash=99beb2cea8922962
]]
