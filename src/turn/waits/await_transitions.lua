local wait_callbacks = require("src.turn.waits.callback_registry")
local timing = require("src.config.gameplay.timing")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local landing_visual_hold = require("src.state.visual_hold")
local tip_queue = require("src.foundation.tips")
local shared = require("src.turn.waits.await_shared")

local _WAIT = shared.WAIT
local _unpack_next = shared.unpack_next
local _mark_dirty = shared.mark_dirty

local callback_keys = wait_callbacks.callback_keys
local wait_keys = wait_callbacks.wait_keys

local function _ensure_landing_callback(game, args)
  if wait_callbacks.peek(game, callback_keys.after_landing_visual) ~= nil then
    return
  end
  wait_callbacks.register(game, callback_keys.after_landing_visual, function()
    return _unpack_next(args)
  end)
end

local function _begin_landing_wait(game)
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

local function _finish_landing_wait(session, args, game, pending_seq)
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

local function _landing_visual(session, args)
  assert(session ~= nil and session.game ~= nil, "missing await session")
  local game = session.game
  session:mark_phase("wait_landing_visual")
  assert(game.turn ~= nil, "missing game.turn")

  _ensure_landing_callback(game, args)

  local pending_seq = wait_callbacks.pending_wait_seq(game, wait_keys.landing_visual)
  if pending_seq == nil then
    return _begin_landing_wait(game)
  end
  if not wait_callbacks.is_wait_ready(game, wait_keys.landing_visual) then
    return _WAIT
  end
  return _finish_landing_wait(session, args, game, pending_seq)
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

local transitions = {}

transitions.landing_visual = _landing_visual
transitions.detained = _detained
transitions.inter_turn = _inter_turn

return transitions

--[[ mutate4lua-manifest
version=2
projectHash=c12c3a64f86b0787
scope.0.id=chunk:src/turn/waits/await_transitions.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=113
scope.0.semanticHash=8f535b0fc635154a
scope.1.id=function:anonymous@19:19
scope.1.kind=function
scope.1.startLine=19
scope.1.endLine=21
scope.1.semanticHash=3e650647ce663b00
scope.2.id=function:_ensure_landing_callback:15
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=22
scope.2.semanticHash=92ecad62f2fe72eb
scope.3.id=function:anonymous@28:28
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=33
scope.3.semanticHash=39dc2487752eb406
scope.4.id=function:_begin_landing_wait:24
scope.4.kind=function
scope.4.startLine=24
scope.4.endLine=35
scope.4.semanticHash=700ccfe0ba71a711
scope.5.id=function:_finish_landing_wait:37
scope.5.kind=function
scope.5.startLine=37
scope.5.endLine=51
scope.5.semanticHash=9196f0ff1c7ccf31
scope.6.id=function:_landing_visual:53
scope.6.kind=function
scope.6.startLine=53
scope.6.endLine=69
scope.6.semanticHash=30f93f38331b1760
scope.7.id=function:_detained:71
scope.7.kind=function
scope.7.startLine=71
scope.7.endLine=83
scope.7.semanticHash=95f7ed91505d11d1
scope.8.id=function:_inter_turn:85
scope.8.kind=function
scope.8.startLine=85
scope.8.endLine=104
scope.8.semanticHash=b599a71619d07bf3
]]
