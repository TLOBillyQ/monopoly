local number_utils = require("src.foundation.number")
local runtime_state = require("src.state.runtime")

local turn_camera_policy = {}

local function _is_follow_candidate(player)
  return player and player.id ~= nil and player.eliminated ~= true
end

local function _game_turn(game)
  return game and game.turn or nil
end

local function _game_players(game)
  return game and game.players or nil
end

local function _validated_player_list(game)
  local turn = _game_turn(game)
  local players = _game_players(game)
  if not (turn and type(players) == "table") then
    return nil, nil, nil
  end
  local count = #players
  if count <= 0 then
    return nil, nil, nil
  end
  local current_index = number_utils.to_integer(turn.current_player_index)
  return players, count, current_index
end

local function _scan_next_candidate(players, count, start_index)
  for offset = 1, count do
    local idx = ((start_index - 1 + offset) % count) + 1
    local candidate = players[idx]
    if _is_follow_candidate(candidate) then
      return candidate.id
    end
  end
  return nil
end

local function _player_at(players, index)
  return index and players[index] or nil
end

local function _resolve_follow_player_id(game)
  local players, count, current_index = _validated_player_list(game)
  if not players then
    return nil
  end
  local current = _player_at(players, current_index)
  if _is_follow_candidate(current) then
    return current.id
  end
  if current_index == nil then
    return nil
  end
  return _scan_next_candidate(players, count, current_index)
end

local function _get_ui_sync_ports(ports)
  local ui_sync_ports = ports and ports.ui_sync or nil
  if not (ui_sync_ports and type(ui_sync_ports.follow_camera) == "function") then
    return nil
  end
  return ui_sync_ports
end

local function _clear_follow_target(turn_runtime)
  if turn_runtime then
    turn_runtime.last_follow_player_id = nil
  end
end

local function _sync_existing_target(ui_sync_ports, state)
  if type(ui_sync_ports.sync_camera_position) == "function" then
    ui_sync_ports.sync_camera_position(state)
  end
end

local function _can_change_target(turn_runtime, ui_refreshed)
  return ui_refreshed == true or turn_runtime ~= nil
end

local function _record_follow_target(turn_runtime, current_id, ok)
  if ok and turn_runtime then
    turn_runtime.last_follow_player_id = current_id
  end
end

local function _resolve_turn_runtime(state)
  return state and runtime_state.ensure_turn_runtime(state) or nil
end

local function _is_target_changed(turn_runtime, current_id)
  return not (turn_runtime and turn_runtime.last_follow_player_id == current_id)
end

local function _is_target_pan_active(turn_runtime)
  return turn_runtime ~= nil and turn_runtime.target_pan_active == true
end

local function _apply_follow(ui_sync_ports, state, turn_runtime, current_id, ui_refreshed)
  if not _is_target_changed(turn_runtime, current_id) then
    _sync_existing_target(ui_sync_ports, state)
    return
  end
  if not _can_change_target(turn_runtime, ui_refreshed) then
    return
  end

  local ok = ui_sync_ports.follow_camera(state, current_id)
  _record_follow_target(turn_runtime, current_id, ok)
end

function turn_camera_policy.sync_follow(game, state, ports, ui_refreshed)
  local ui_sync_ports = _get_ui_sync_ports(ports)
  if not ui_sync_ports then
    return
  end

  local turn_runtime = _resolve_turn_runtime(state)
  -- 效果平移(pan)存活期内整体跳过:此时 dirty.turn 清掉 last_follow 只是
  -- visual hold 等机制的心跳,不是换目标;重放 follow 会把镜头从效果地块
  -- 拽回玩家(效果结算偶发 jitter)。release_target_pan 清标志后恢复跟随。
  if _is_target_pan_active(turn_runtime) then
    return
  end
  local current_id = _resolve_follow_player_id(game)
  if current_id == nil then
    _clear_follow_target(turn_runtime)
    return
  end

  _apply_follow(ui_sync_ports, state, turn_runtime, current_id, ui_refreshed)
end

function turn_camera_policy.reset_follow(state)
  local turn_runtime = state and runtime_state.ensure_turn_runtime(state) or nil
  if turn_runtime then
    turn_runtime.last_follow_player_id = nil
  end
end

turn_camera_policy._resolve_follow_player_id = _resolve_follow_player_id

return turn_camera_policy

--[[ mutate4lua-manifest
version=4
projectHash=e6e44155293f7b5e
scope.0.id=chunk:src/turn/policies/camera.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=149
scope.0.semanticHash=0f471f56f85fec4a
scope.1.id=function:_is_follow_candidate
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=8
scope.1.semanticHash=95b8e78cdc5e07f8
scope.2.id=function:_game_turn
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=12
scope.2.semanticHash=616a2ca60599c94f
scope.3.id=function:_game_players
scope.3.kind=function
scope.3.startLine=14
scope.3.endLine=16
scope.3.semanticHash=616a2ca60599c94f
scope.4.id=function:_validated_player_list
scope.4.kind=function
scope.4.startLine=18
scope.4.endLine=30
scope.4.semanticHash=ce1ffaf95106402d
scope.5.id=function:_scan_next_candidate
scope.5.kind=function
scope.5.startLine=32
scope.5.endLine=41
scope.5.semanticHash=44b2677fe50d4362
scope.6.id=function:_player_at
scope.6.kind=function
scope.6.startLine=43
scope.6.endLine=45
scope.6.semanticHash=cd6b189045fad21d
scope.7.id=function:_resolve_follow_player_id
scope.7.kind=function
scope.7.startLine=47
scope.7.endLine=60
scope.7.semanticHash=cd697a2c169d15f0
scope.8.id=function:_get_ui_sync_ports
scope.8.kind=function
scope.8.startLine=62
scope.8.endLine=68
scope.8.semanticHash=46d6af7469a6e44a
scope.9.id=function:_clear_follow_target
scope.9.kind=function
scope.9.startLine=70
scope.9.endLine=74
scope.9.semanticHash=8868fb2d52ba0634
scope.10.id=function:_sync_existing_target
scope.10.kind=function
scope.10.startLine=76
scope.10.endLine=80
scope.10.semanticHash=6892d552c18bbb39
scope.11.id=function:_can_change_target
scope.11.kind=function
scope.11.startLine=82
scope.11.endLine=84
scope.11.semanticHash=f197a21d7cb30a61
scope.12.id=function:_record_follow_target
scope.12.kind=function
scope.12.startLine=86
scope.12.endLine=90
scope.12.semanticHash=175107b1c1e1f276
scope.13.id=function:_resolve_turn_runtime
scope.13.kind=function
scope.13.startLine=92
scope.13.endLine=94
scope.13.semanticHash=031bc6768e248ce0
scope.14.id=function:_is_target_changed
scope.14.kind=function
scope.14.startLine=96
scope.14.endLine=98
scope.14.semanticHash=a81a04b274cb4cdd
scope.15.id=function:_is_target_pan_active
scope.15.kind=function
scope.15.startLine=100
scope.15.endLine=102
scope.15.semanticHash=be8994585243633b
scope.16.id=function:_apply_follow
scope.16.kind=function
scope.16.startLine=104
scope.16.endLine=115
scope.16.semanticHash=d1df7e863b9a856b
scope.17.id=function:turn_camera_policy.sync_follow
scope.17.kind=function
scope.17.startLine=117
scope.17.endLine=137
scope.17.semanticHash=3279c8bf9712a4b2
scope.18.id=function:turn_camera_policy.reset_follow
scope.18.kind=function
scope.18.startLine=139
scope.18.endLine=144
scope.18.semanticHash=af7be966dcb66aa9
]]
