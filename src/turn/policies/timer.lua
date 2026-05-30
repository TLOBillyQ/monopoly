local constants = require("src.config.content.constants")
local tip_queue = require("src.foundation.tips")

local turn_timer_policy = {}

local function _reset_action_button(state)
  state.action_button_active = false
  state.action_button_elapsed = 0
  state.action_button_player_id = nil
end

local function _has_blocking_ui(ui_sync_ports, state)
  return (ui_sync_ports and ui_sync_ports.is_choice_active and ui_sync_ports.is_choice_active(state))
      or (ui_sync_ports and ui_sync_ports.is_popup_active and ui_sync_ports.is_popup_active(state))
end

local function _is_ui_state_absent(ui_sync_ports, state)
  return ui_sync_ports
    and ui_sync_ports.get_ui_state
    and not ui_sync_ports.get_ui_state(state)
end

local function _is_input_blocked_port(ui_sync_ports, state)
  return ui_sync_ports
    and ui_sync_ports.is_input_blocked
    and ui_sync_ports.is_input_blocked(state)
end

local function _resolve_elapsed(elapsed, dt)
  return (elapsed or 0) + (dt or 0)
end

local function _complete_wait(turn, active_key, elapsed_key, step_turn, game)
  turn[active_key] = false
  turn[elapsed_key] = 0
  step_turn(game)
end

local function _get_valid_ui_sync(game, state, ports)
  if not (game and state and ports) then
    return nil, false
  end
  return ports.ui_sync, true
end

function turn_timer_policy.is_action_button_wait_active(game, state, ports)
  local ui_sync_ports, is_valid = _get_valid_ui_sync(game, state, ports)
  if not is_valid then
    return false
  end
  if _is_ui_state_absent(ui_sync_ports, state) then
    return false
  end
  if game.finished then
    return false
  end
  if _is_input_blocked_port(ui_sync_ports, state) then
    return false
  end
  if _has_blocking_ui(ui_sync_ports, state) then
    return false
  end
  if game.turn and game.turn.pending_choice then
    return false
  end
  return true
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

local function _resolve_action_timer_context(ctx)
  local state = ctx and ctx.state
  if not state then
    return nil
  end
  local game = ctx.game
  local ports = ctx.ports
  if not turn_timer_policy.is_action_button_wait_active(game, state, ports) then
    return nil
  end
  local timeout = constants.action_timeout_seconds or 0
  if timeout <= 0 then
    return nil
  end
  local current_player = _resolve_current_player(game)
  if not current_player then
    return nil
  end
  if not _should_track_action_button_for_player(game, current_player) then
    return nil
  end
  return state, game, timeout, current_player
end

function turn_timer_policy.update_action_button_timer(ctx)
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

local function _wait_timer(game, state, dt, step_turn, active_key, elapsed_key, timeout_key, before_complete)
  if not (game and state) then
    return
  end
  local turn = game.turn
  if not (turn and turn[active_key]) then
    return
  end

  local elapsed = _resolve_elapsed(turn[elapsed_key], dt)
  local timeout = turn[timeout_key] or 0
  if timeout <= 0 then
    _complete_wait(turn, active_key, elapsed_key, step_turn, game)
    return
  end
  if elapsed < timeout then
    turn[elapsed_key] = elapsed
    return
  end

  if before_complete and before_complete(turn, timeout) == false then
    return
  end

  _complete_wait(turn, active_key, elapsed_key, step_turn, game)
end

function turn_timer_policy.update_detained_wait_timer(game, state, dt, step_turn)
  _wait_timer(game, state, dt, step_turn,
    "detained_wait_active", "detained_wait_elapsed", "detained_wait_seconds", nil)
end

local function _inter_turn_before_complete(turn, timeout)
  turn.inter_turn_wait_elapsed = timeout
  if tip_queue.has_blocking_pending("inter_turn") then
    return false
  end
  return true
end

function turn_timer_policy.update_inter_turn_wait_timer(game, state, dt, step_turn)
  _wait_timer(game, state, dt, step_turn,
    "inter_turn_wait_active", "inter_turn_wait_elapsed", "inter_turn_wait_seconds",
    _inter_turn_before_complete)
end

return turn_timer_policy

--[[ mutate4lua-manifest
version=2
projectHash=9333334ac19df88a
scope.0.id=chunk:src/turn/policies/timer.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=212
scope.0.semanticHash=eb00f8c70cd4fc61
scope.1.id=function:_reset_action_button:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=10
scope.1.semanticHash=ccbb2b20430024bd
scope.2.id=function:_has_blocking_ui:12
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=15
scope.2.semanticHash=b2dfbbffacaa2abc
scope.3.id=function:_is_ui_state_absent:17
scope.3.kind=function
scope.3.startLine=17
scope.3.endLine=21
scope.3.semanticHash=8a5d0a83abd5b53d
scope.4.id=function:_is_input_blocked_port:23
scope.4.kind=function
scope.4.startLine=23
scope.4.endLine=27
scope.4.semanticHash=27f9bc4e781bc073
scope.5.id=function:_resolve_elapsed:29
scope.5.kind=function
scope.5.startLine=29
scope.5.endLine=31
scope.5.semanticHash=45538442d3a1a35c
scope.6.id=function:_complete_wait:33
scope.6.kind=function
scope.6.startLine=33
scope.6.endLine=37
scope.6.semanticHash=6bdf4de041312382
scope.7.id=function:_get_valid_ui_sync:39
scope.7.kind=function
scope.7.startLine=39
scope.7.endLine=44
scope.7.semanticHash=fec753337eed910b
scope.8.id=function:turn_timer_policy.is_action_button_wait_active:46
scope.8.kind=function
scope.8.startLine=46
scope.8.endLine=67
scope.8.semanticHash=eebb5fb1f9317538
scope.9.id=function:_resolve_current_player:70
scope.9.kind=function
scope.9.startLine=70
scope.9.endLine=73
scope.9.semanticHash=502e9032a5f33b78
scope.10.id=function:_is_auto_player:75
scope.10.kind=function
scope.10.startLine=75
scope.10.endLine=87
scope.10.semanticHash=c35129374ec652fc
scope.11.id=function:_should_track_action_button_for_player:89
scope.11.kind=function
scope.11.startLine=89
scope.11.endLine=95
scope.11.semanticHash=dbb6998e2d93e551
scope.12.id=function:_update_elapsed_timer:97
scope.12.kind=function
scope.12.startLine=97
scope.12.endLine=104
scope.12.semanticHash=aeddd1dea6466ad7
scope.13.id=function:_handle_timeout_elapsed:106
scope.13.kind=function
scope.13.startLine=106
scope.13.endLine=115
scope.13.semanticHash=18fd520517f44910
scope.14.id=function:_resolve_action_timer_context:117
scope.14.kind=function
scope.14.startLine=117
scope.14.endLine=139
scope.14.semanticHash=c05dcd506c5e4311
scope.15.id=function:turn_timer_policy.update_action_button_timer:141
scope.15.kind=function
scope.15.startLine=141
scope.15.endLine=163
scope.15.semanticHash=1031ae33352c8cfe
scope.16.id=function:_wait_timer:165
scope.16.kind=function
scope.16.startLine=165
scope.16.endLine=190
scope.16.semanticHash=6828514ee859beaa
scope.17.id=function:turn_timer_policy.update_detained_wait_timer:192
scope.17.kind=function
scope.17.startLine=192
scope.17.endLine=195
scope.17.semanticHash=9bcdbb8b6769a02b
scope.18.id=function:_inter_turn_before_complete:197
scope.18.kind=function
scope.18.startLine=197
scope.18.endLine=203
scope.18.semanticHash=0fdeda5aba3f9a2a
scope.19.id=function:turn_timer_policy.update_inter_turn_wait_timer:205
scope.19.kind=function
scope.19.startLine=205
scope.19.endLine=209
scope.19.semanticHash=3ab240ad915ac011
]]
