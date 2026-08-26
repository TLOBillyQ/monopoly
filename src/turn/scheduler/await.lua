local control = require("src.player.control")
local turn_decision = require("src.turn.waits.decision")
local validator = require("src.turn.actions.validator")
local chain_args = require("src.foundation.chain_args")
local shared = require("src.turn.waits.await_shared")
local action_anim = require("src.turn.waits.await_action_anim")
local move_anim = require("src.turn.waits.await_move_anim")
local transitions = require("src.turn.waits.await_transitions")
local seconds = require("src.turn.waits.await_seconds")

local _WAIT = shared.WAIT
local _unpack_next = shared.unpack_next
local _mark_dirty = shared.mark_dirty

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
  if control.is_computer_controlled(player) then
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

-- 共享 decide 入参表;elapsed_seconds 在 _resolve_choice_action 调用前恒被覆写,
-- 初值 0 恒不可读(等价变异体,按 #257 三分类删冗余)。
local _decide_opts = {}

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
    -- game 与 game.turn 恒非 nil(_choice 入口断言 + pending_choice 读取把守),
    -- 「game and game.turn」是恒真守卫(等价变异体,按 #257 三分类删冗余)。
    game.turn.pending_choice = nil
    _mark_dirty(game)
    return {}, true
  end
  return turn_decision.resolve_choice(game, choice, action), true
end

local function _finish_choice_wait(session, args, game, res)
  if res and res.stay then
    return _WAIT
  end
  local next_state, next_args = _resolve_after_action_anim(args, res)
  if next_state ~= "wait_choice" then
    session.choice_elapsed_seconds = 0
  end
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
    -- choice 恒非 nil(唯一调用方 _resolve_choice_result 由 _choice 的
    -- not-choice 短路把守),「choice and」是恒真守卫(等价变异体,删冗余)。
    return { type = "choice_force_skip", choice_id = choice.id }
  end
  _decide_opts.elapsed_seconds = session.choice_elapsed_seconds or 0
  return turn_decision.decide_choice_action(game, choice, session:take_pending_action(), _decide_opts)
end

_validate_choice_action = function(action, choice)
  -- choice_force_skip 不设独立分支:它 ~= choice_select 且 ~= choice_cancel,
  -- 由下面的类型闸门天然放行——早退分支是逐位等价的死代码(变异清扫删冗余)。
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

---@class TurnAwaitHandlers
---@field action fun(session: table, args: table?): table?
---@field choice fun(session: table, args: table?): table?
---@field move_anim fun(session: table, args: table?): table?
---@field action_anim fun(session: table, args: table?): table?
---@field landing_visual fun(session: table, args: table?): table?
---@field detained fun(session: table, args: table?): table?
---@field inter_turn fun(session: table, args: table?): table?
---@field seconds fun(session: table, sec: number?, opts: table?): table?
---@type TurnAwaitHandlers
local await = {
  choice = _choice,
  action = _action,
  move_anim = move_anim.move_anim,
  action_anim = action_anim.action_anim,
  landing_visual = transitions.landing_visual,
  detained = transitions.detained,
  inter_turn = transitions.inter_turn,
  seconds = seconds.seconds,
}

return await

--[[ mutate4lua-manifest
version=4
projectHash=b6c5747e93b897c8
scope.0.id=chunk:src/turn/scheduler/await.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=181
scope.0.semanticHash=a4dcfd60888562c3
scope.1.id=function:_is_choice_action
scope.1.kind=function
scope.1.startLine=17
scope.1.endLine=20
scope.1.semanticHash=c0c9dcb02f1e8278
scope.2.id=function:_build_action_next
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=27
scope.2.semanticHash=c46e9d15a886dc0d
scope.3.id=function:_action
scope.3.kind=function
scope.3.startLine=29
scope.3.endLine=47
scope.3.semanticHash=5c6824da94dd0d38
scope.4.id=function:_resolve_after_action_anim
scope.4.kind=function
scope.4.startLine=57
scope.4.endLine=59
scope.4.semanticHash=09b724016540ebed
scope.5.id=function:_clear_choice_wait
scope.5.kind=function
scope.5.startLine=61
scope.5.endLine=69
scope.5.semanticHash=42a5c728b3256aa6
scope.6.id=function:_resolve_choice_result
scope.6.kind=function
scope.6.startLine=71
scope.6.endLine=87
scope.6.semanticHash=84b2e060cf2e3ddc
scope.7.id=function:_finish_choice_wait
scope.7.kind=function
scope.7.startLine=89
scope.7.endLine=104
scope.7.semanticHash=ec596b5c67d80767
scope.8.id=function:_resolve_choice_action
scope.8.kind=function
scope.8.startLine=106
scope.8.endLine=115
scope.8.semanticHash=7c5468151969ee51
scope.9.id=function:_validate_choice_action
scope.9.kind=function
scope.9.startLine=117
scope.9.endLine=124
scope.9.semanticHash=650032ae591e38ca
scope.10.id=function:_wait_for_choice_action_anim
scope.10.kind=function
scope.10.startLine=126
scope.10.endLine=138
scope.10.semanticHash=96ebcfa0e197c919
scope.11.id=function:_choice
scope.11.kind=function
scope.11.startLine=140
scope.11.endLine=157
scope.11.semanticHash=ea028ef8c8d9cbd1
]]
