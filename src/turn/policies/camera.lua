local number_utils = require("src.foundation.number")
local runtime_state = require("src.state.runtime")

local turn_camera_policy = {}

local function _is_follow_candidate(player)
  return player and player.id ~= nil and player.eliminated ~= true
end

local function _validated_player_list(game)
  local turn = game and game.turn or nil
  local players = game and game.players or nil
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

local function _resolve_follow_player_id(game)
  local players, count, current_index = _validated_player_list(game)
  if not players then
    return nil
  end
  local current = current_index and players[current_index] or nil
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

function turn_camera_policy.sync_follow(game, state, ports, ui_refreshed)
  local ui_sync_ports = _get_ui_sync_ports(ports)
  if not ui_sync_ports then
    return
  end

  local turn_runtime = state and runtime_state.ensure_turn_runtime(state) or nil
  local current_id = _resolve_follow_player_id(game)
  if current_id == nil then
    _clear_follow_target(turn_runtime)
    return
  end

  local target_changed = not (turn_runtime and turn_runtime.last_follow_player_id == current_id)
  if not target_changed then
    _sync_existing_target(ui_sync_ports, state)
    return
  end
  if not _can_change_target(turn_runtime, ui_refreshed) then
    return
  end

  local ok = ui_sync_ports.follow_camera(state, current_id)
  _record_follow_target(turn_runtime, current_id, ok)
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
version=2
projectHash=bfc27ea27623a8a9
scope.0.id=chunk:src/turn/policies/camera.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=116
scope.0.semanticHash=0ecad5f5615a3dc9
scope.1.id=function:_is_follow_candidate:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=8
scope.1.semanticHash=c07a823ed097967e
scope.2.id=function:_validated_player_list:10
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=22
scope.2.semanticHash=57b6d79c78ce7354
scope.3.id=function:_resolve_follow_player_id:35
scope.3.kind=function
scope.3.startLine=35
scope.3.endLine=48
scope.3.semanticHash=094764c9cddde98a
scope.4.id=function:_get_ui_sync_ports:50
scope.4.kind=function
scope.4.startLine=50
scope.4.endLine=56
scope.4.semanticHash=4f01a0571bacca24
scope.5.id=function:_clear_follow_target:58
scope.5.kind=function
scope.5.startLine=58
scope.5.endLine=62
scope.5.semanticHash=ed7dbf86ef5947a6
scope.6.id=function:_sync_existing_target:64
scope.6.kind=function
scope.6.startLine=64
scope.6.endLine=68
scope.6.semanticHash=ec67293f77b047a3
scope.7.id=function:_can_change_target:70
scope.7.kind=function
scope.7.startLine=70
scope.7.endLine=72
scope.7.semanticHash=534233defaf0d258
scope.8.id=function:_record_follow_target:74
scope.8.kind=function
scope.8.startLine=74
scope.8.endLine=78
scope.8.semanticHash=7fe0bd998b42a436
scope.9.id=function:turn_camera_policy.sync_follow:80
scope.9.kind=function
scope.9.startLine=80
scope.9.endLine=104
scope.9.semanticHash=96804d243dc51b1c
scope.10.id=function:turn_camera_policy.reset_follow:106
scope.10.kind=function
scope.10.startLine=106
scope.10.endLine=111
scope.10.semanticHash=662c4e298284c1ef
]]
