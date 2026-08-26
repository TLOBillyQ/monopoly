local constants = require("src.config.content.constants")
local action_button_wait = require("src.turn.policies.action_button_wait")
local afk_signal = require("src.turn.policies.afk_signal")
local control = require("src.player.control")

local action_button_timer = {}

local function _reset_action_button(state)
  state.action_button_active = false
  state.action_button_elapsed = 0
  state.action_button_player_id = nil
end

function action_button_timer.resolve_elapsed(elapsed, dt)
  return (elapsed or 0) + (dt or 0)
end

local function _current_player_index(game)
  return game and game.turn and game.turn.current_player_index or nil
end

local function _player_at_index(game, current_index)
  return current_index and game.players and game.players[current_index] or nil
end

local function _resolve_current_player(game)
  return _player_at_index(game, _current_player_index(game))
end

local function _should_track_action_button_for_player(game, player)
  if control.is_computer_controlled(player) then
    return true
  end
  local phase = game and game.turn and game.turn.phase or nil
  return phase == "wait_action"
end

local function _update_elapsed_timer(state, dt, timeout)
  local elapsed = action_button_timer.resolve_elapsed(state.action_button_elapsed, dt)
  if elapsed < timeout then
    state.action_button_elapsed = elapsed
    return true
  end
  return false
end

local function _handle_timeout_elapsed(state, game, ctx)
  state.action_button_elapsed = 0
  local current_player = _resolve_current_player(game)
  if not current_player then
    return
  end
  if afk_signal.is_timeout_eligible(current_player) then
    afk_signal.on_timeout_fallback(game, state, current_player.id, "action_button")
  end
  if ctx.dispatch_next then
    ctx.dispatch_next(current_player.id, "timeout")
  end
end

local function _resolve_active_timeout(game, state, ports)
  if not action_button_wait.is_action_button_wait_active(game, state, ports) then
    return nil
  end
  local timeout = constants.action_timeout_seconds or 0
  if timeout <= 0 then
    return nil
  end
  return timeout
end

local function _resolve_tracked_player(game)
  local current_player = _resolve_current_player(game)
  if not current_player then
    return nil
  end
  if not _should_track_action_button_for_player(game, current_player) then
    return nil
  end
  return current_player
end

local function _resolve_action_timer_context(ctx)
  local state = ctx and ctx.state
  if not state then
    return nil
  end
  local game = ctx.game
  local timeout = _resolve_active_timeout(game, state, ctx.ports)
  if not timeout then
    return nil
  end
  local current_player = _resolve_tracked_player(game)
  if not current_player then
    return nil
  end
  return state, game, timeout, current_player
end

-- 上下文不成立时，仍要把 ctx 上挂着的 state 复位。
local function _reset_from_ctx(ctx)
  local state = ctx and ctx.state
  if state then
    _reset_action_button(state)
  end
end

function action_button_timer.update_action_button_timer(ctx)
  local state, game, timeout, current_player = _resolve_action_timer_context(ctx)
  if not state then
    _reset_from_ctx(ctx)
    return
  end

  if state.action_button_player_id ~= current_player.id then
    state.action_button_player_id = current_player.id
    state.action_button_elapsed = 0
  end

  state.action_button_active = true

  if _update_elapsed_timer(state, ctx.dt, timeout) then
    return
  end

  _handle_timeout_elapsed(state, game, ctx)
end

return action_button_timer

--[[ mutate4lua-manifest
version=4
projectHash=eee80f10a43fc7a6
scope.0.id=chunk:src/turn/policies/action_button_timer.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=130
scope.0.semanticHash=914098e10f142736
scope.1.id=function:_reset_action_button
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=12
scope.1.semanticHash=9518a358c8c4df0f
scope.2.id=function:action_button_timer.resolve_elapsed
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=16
scope.2.semanticHash=fa436a84bd951919
scope.3.id=function:_current_player_index
scope.3.kind=function
scope.3.startLine=18
scope.3.endLine=20
scope.3.semanticHash=c250138038aa193a
scope.4.id=function:_player_at_index
scope.4.kind=function
scope.4.startLine=22
scope.4.endLine=24
scope.4.semanticHash=bafa57000621798c
scope.5.id=function:_resolve_current_player
scope.5.kind=function
scope.5.startLine=26
scope.5.endLine=28
scope.5.semanticHash=659b4a5266e78baa
scope.6.id=function:_should_track_action_button_for_player
scope.6.kind=function
scope.6.startLine=30
scope.6.endLine=36
scope.6.semanticHash=d1082928dac15d34
scope.7.id=function:_update_elapsed_timer
scope.7.kind=function
scope.7.startLine=38
scope.7.endLine=45
scope.7.semanticHash=3145ee3ca1983481
scope.8.id=function:_handle_timeout_elapsed
scope.8.kind=function
scope.8.startLine=47
scope.8.endLine=59
scope.8.semanticHash=bc5c46ec5c9198be
scope.9.id=function:_resolve_active_timeout
scope.9.kind=function
scope.9.startLine=61
scope.9.endLine=70
scope.9.semanticHash=32017f70566c7884
scope.10.id=function:_resolve_tracked_player
scope.10.kind=function
scope.10.startLine=72
scope.10.endLine=81
scope.10.semanticHash=19efc6234af300d4
scope.11.id=function:_resolve_action_timer_context
scope.11.kind=function
scope.11.startLine=83
scope.11.endLine=98
scope.11.semanticHash=a440e08fed721b67
scope.12.id=function:_reset_from_ctx
scope.12.kind=function
scope.12.startLine=101
scope.12.endLine=106
scope.12.semanticHash=d7ea3951c3aaa1f8
scope.13.id=function:action_button_timer.update_action_button_timer
scope.13.kind=function
scope.13.startLine=108
scope.13.endLine=127
scope.13.semanticHash=196e11d2ac1e4fce
]]
