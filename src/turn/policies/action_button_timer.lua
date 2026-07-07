local constants = require("src.config.content.constants")
local action_button_wait = require("src.turn.policies.action_button_wait")

local action_button_timer = {}

local function _reset_action_button(state)
  state.action_button_active = false
  state.action_button_elapsed = 0
  state.action_button_player_id = nil
end

local function _resolve_elapsed(elapsed, dt)
  return (elapsed or 0) + (dt or 0)
end

local function _resolve_current_player(game)
  local current_index = game and game.turn and game.turn.current_player_index or nil
  return current_index and game.players and game.players[current_index] or nil
end

local function _is_auto_player(game, player)
  if not player then
    return false
  end
  local auto_play_port = game and game.auto_play_port or nil
  if type(auto_play_port) == "table" and type(auto_play_port.is_auto_player) == "function" then
    local ok, is_auto = pcall(auto_play_port.is_auto_player, game, player)
    if ok then
      return is_auto == true
    end
  end
  return player.auto == true or player.is_ai == true or player.ai == true
end

local function _should_track_action_button_for_player(game, player)
  if _is_auto_player(game, player) then
    return true
  end
  local phase = game and game.turn and game.turn.phase or nil
  return phase == "wait_action"
end

local function _update_elapsed_timer(state, dt, timeout)
  local elapsed = _resolve_elapsed(state.action_button_elapsed, dt)
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

function action_button_timer.update_action_button_timer(ctx)
  local state, game, timeout, current_player = _resolve_action_timer_context(ctx)
  if not state then
    local s = ctx and ctx.state
    if s then
      _reset_action_button(s)
    end
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
version=2
projectHash=71c3b6a942874640
scope.0.id=chunk:src/turn/policies/action_button_timer.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=127
scope.0.semanticHash=257d5140f4b32b9a
scope.1.id=function:_reset_action_button:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=10
scope.1.semanticHash=ccbb2b20430024bd
scope.2.id=function:_resolve_elapsed:12
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=14
scope.2.semanticHash=45538442d3a1a35c
scope.3.id=function:_resolve_current_player:16
scope.3.kind=function
scope.3.startLine=16
scope.3.endLine=19
scope.3.semanticHash=502e9032a5f33b78
scope.4.id=function:_is_auto_player:21
scope.4.kind=function
scope.4.startLine=21
scope.4.endLine=33
scope.4.semanticHash=c35129374ec652fc
scope.5.id=function:_should_track_action_button_for_player:35
scope.5.kind=function
scope.5.startLine=35
scope.5.endLine=41
scope.5.semanticHash=dbb6998e2d93e551
scope.6.id=function:_update_elapsed_timer:43
scope.6.kind=function
scope.6.startLine=43
scope.6.endLine=50
scope.6.semanticHash=aeddd1dea6466ad7
scope.7.id=function:_handle_timeout_elapsed:52
scope.7.kind=function
scope.7.startLine=52
scope.7.endLine=61
scope.7.semanticHash=18fd520517f44910
scope.8.id=function:_resolve_active_timeout:63
scope.8.kind=function
scope.8.startLine=63
scope.8.endLine=72
scope.8.semanticHash=15e545ca604fd575
scope.9.id=function:_resolve_tracked_player:74
scope.9.kind=function
scope.9.startLine=74
scope.9.endLine=83
scope.9.semanticHash=9031bb3e5ac97528
scope.10.id=function:_resolve_action_timer_context:85
scope.10.kind=function
scope.10.startLine=85
scope.10.endLine=100
scope.10.semanticHash=3e8ebf2535ac781d
scope.11.id=function:action_button_timer.update_action_button_timer:102
scope.11.kind=function
scope.11.startLine=102
scope.11.endLine=124
scope.11.semanticHash=ca349ce47bae284d
]]
