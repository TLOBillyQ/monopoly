local move_anim_debug = require("src.foundation.move_anim_debug")
local shared = require("src.turn.waits.await_shared")

local _WAIT = shared.WAIT
local _unpack_next = shared.unpack_next
local _mark_dirty = shared.mark_dirty

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

local function _field_text(source, key)
  return tostring(source and source[key] or "nil")
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
    "phase=" .. _field_text(turn, "phase"),
    "anim_seq=" .. _field_text(anim, "seq"),
    "pending_action_type=" .. _field_text(action, "type"),
    "pending_action_seq=" .. _field_text(action, "seq")
  )
end

local _cached_anim_opts = {
  state_name = nil,
  anim_key = nil,
  done_action_type = nil,
}

local function _opt_or(opts, key, fallback)
  return opts and opts[key] or fallback
end

local function _resolve_wait_anim_opts(opts)
  _cached_anim_opts.state_name = _opt_or(opts, "state_name", "wait_move_anim")
  _cached_anim_opts.anim_key = _opt_or(opts, "anim_key", "move_anim")
  _cached_anim_opts.done_action_type = _opt_or(opts, "done_action_type", "move_anim_done")
  return _cached_anim_opts
end

local function _assert_await_anim_args(session, opts)
  assert(session ~= nil and session.game ~= nil, "missing await session")
  -- opts 三件套(state_name/anim_key/done_action_type)恒被唯一调用方
  -- _resolve_wait_anim_opts 填满,曾经的三个 nil 断言恒不触发——
  -- 等价变异体,按 #257 三分类删冗余。
end

-- action 是否是本次动画的完成信号：类型匹配，且 seq 不与动画冲突。
local function _is_anim_done_action(action, anim, done_action_type)
  if not action or action.type ~= done_action_type then
    return false
  end
  return not (action.seq and anim.seq and action.seq ~= anim.seq)
end

local function _await_anim_done(session, args, opts)
  _assert_await_anim_args(session, opts)
  local game = session.game
  session:mark_phase(opts.state_name)
  local anim = game.turn[opts.anim_key]
  assert(anim ~= nil, "missing " .. tostring(opts.anim_key))
  local action = session:take_pending_action()
  if not _is_anim_done_action(action, anim, opts.done_action_type) then
    return _WAIT
  end
  game.turn[opts.anim_key] = nil
  _mark_dirty(game)
  local next_state, next_args = _unpack_next(args)
  return { next_state = next_state, next_args = next_args }
end

local move_anim = {}

function move_anim.move_anim(session, args, opts)
  if move_anim_debug.enabled() then
    _log_move_anim_wait(session, opts)
  end
  return _await_anim_done(session, args, _resolve_wait_anim_opts(opts))
end

return move_anim

--[[ mutate4lua-manifest
version=4
projectHash=2cd0b76f1abc0133
scope.0.id=chunk:src/turn/waits/await_move_anim.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=102
scope.0.semanticHash=2266a5313a1ebda0
scope.1.id=function:_session_game
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=10
scope.1.semanticHash=616a2ca60599c94f
scope.2.id=function:_turn_from_game
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=14
scope.2.semanticHash=616a2ca60599c94f
scope.3.id=function:_turn_anim
scope.3.kind=function
scope.3.startLine=16
scope.3.endLine=18
scope.3.semanticHash=cd6b189045fad21d
scope.4.id=function:_peek_pending_action
scope.4.kind=function
scope.4.startLine=20
scope.4.endLine=22
scope.4.semanticHash=9ff044378783fe73
scope.5.id=function:_field_text
scope.5.kind=function
scope.5.startLine=24
scope.5.endLine=26
scope.5.semanticHash=1e52cc795e2c0869
scope.6.id=function:_log_move_anim_wait
scope.6.kind=function
scope.6.startLine=28
scope.6.endLine=42
scope.6.semanticHash=39e24e66ddffbff2
scope.7.id=function:_opt_or
scope.7.kind=function
scope.7.startLine=50
scope.7.endLine=52
scope.7.semanticHash=342fa04d54896db7
scope.8.id=function:_resolve_wait_anim_opts
scope.8.kind=function
scope.8.startLine=54
scope.8.endLine=59
scope.8.semanticHash=0c90b7709194ccfb
scope.9.id=function:_assert_await_anim_args
scope.9.kind=function
scope.9.startLine=61
scope.9.endLine=66
scope.9.semanticHash=12d47d728da1b099
scope.10.id=function:_is_anim_done_action
scope.10.kind=function
scope.10.startLine=69
scope.10.endLine=74
scope.10.semanticHash=b771ef146c975b54
scope.11.id=function:_await_anim_done
scope.11.kind=function
scope.11.startLine=76
scope.11.endLine=90
scope.11.semanticHash=a6bf888ee50e6d7a
scope.12.id=function:move_anim.move_anim
scope.12.kind=function
scope.12.startLine=94
scope.12.endLine=99
scope.12.semanticHash=21b455dd3093d2d4
]]
