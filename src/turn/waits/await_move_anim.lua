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

local move_anim = {}

function move_anim.move_anim(session, args, opts)
  if move_anim_debug.enabled() then
    _log_move_anim_wait(session, opts)
  end
  return _await_anim_done(session, args, _resolve_wait_anim_opts(opts))
end

return move_anim

--[[ mutate4lua-manifest
version=2
projectHash=f376d62d6197f0c1
scope.0.id=chunk:src/turn/waits/await_move_anim.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=85
scope.0.semanticHash=ae222ec288aee797
scope.1.id=function:_session_game:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=10
scope.1.semanticHash=51171dcfb18b4304
scope.2.id=function:_turn_from_game:12
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=14
scope.2.semanticHash=4ed39ac00ceb02a5
scope.3.id=function:_turn_anim:16
scope.3.kind=function
scope.3.startLine=16
scope.3.endLine=18
scope.3.semanticHash=b901f0989aca19cd
scope.4.id=function:_peek_pending_action:20
scope.4.kind=function
scope.4.startLine=20
scope.4.endLine=22
scope.4.semanticHash=d663a0c2e1f97b09
scope.5.id=function:_log_move_anim_wait:24
scope.5.kind=function
scope.5.startLine=24
scope.5.endLine=38
scope.5.semanticHash=a0d890930b4efdf9
scope.6.id=function:_resolve_wait_anim_opts:46
scope.6.kind=function
scope.6.startLine=46
scope.6.endLine=51
scope.6.semanticHash=819b97ba44b3d2c6
scope.7.id=function:_await_anim_done:53
scope.7.kind=function
scope.7.startLine=53
scope.7.endLine=73
scope.7.semanticHash=4fe005492aff8495
scope.8.id=function:move_anim.move_anim:77
scope.8.kind=function
scope.8.startLine=77
scope.8.endLine=82
scope.8.semanticHash=3b08f56d9c211f23
]]
