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

function turn_camera_policy.sync_follow(game, state, ports, ui_refreshed)
  local ui_sync_ports = _get_ui_sync_ports(ports)
  if not ui_sync_ports then
    return
  end

  local turn_runtime = state and runtime_state.ensure_turn_runtime(state) or nil
  local current_id = _resolve_follow_player_id(game)
  if current_id == nil then
    if turn_runtime then
      turn_runtime.last_follow_player_id = nil
    end
    return
  end

  local target_changed = not (turn_runtime and turn_runtime.last_follow_player_id == current_id)
  if not target_changed then
    if type(ui_sync_ports.sync_camera_position) == "function" then
      ui_sync_ports.sync_camera_position(state)
    end
    return
  end
  if ui_refreshed ~= true and turn_runtime == nil then
    return
  end

  local ok = ui_sync_ports.follow_camera(state, current_id)
  if ok and turn_runtime then
    turn_runtime.last_follow_player_id = current_id
  end
end

function turn_camera_policy.reset_follow(state)
  local turn_runtime = state and runtime_state.ensure_turn_runtime(state) or nil
  if turn_runtime then
    turn_runtime.last_follow_player_id = nil
  end
end

turn_camera_policy._resolve_follow_player_id = _resolve_follow_player_id

return turn_camera_policy
