local number_utils = require("src.core.utils.number_utils")

local turn_camera_policy = {}

local function _resolve_follow_player_id(game)
  local turn = game and game.turn or nil
  local players = game and game.players or nil
  if not (turn and type(players) == "table") then
    return nil
  end
  local count = #players
  if count <= 0 then
    return nil
  end
  local current_index = number_utils.to_integer(turn.current_player_index)
  local current = current_index and players[current_index] or nil
  if current and current.id ~= nil and current.eliminated ~= true then
    return current.id
  end
  if current_index == nil then
    return nil
  end
  for offset = 1, count do
    local idx = ((current_index - 1 + offset) % count) + 1
    local candidate = players[idx]
    if candidate and candidate.id ~= nil and candidate.eliminated ~= true then
      return candidate.id
    end
  end
  return nil
end

function turn_camera_policy.sync_follow(game, state, ports, ui_refreshed)
  if ui_refreshed ~= true then
    return
  end

  local ui_sync_ports = ports and ports.ui_sync or nil
  if not (ui_sync_ports and type(ui_sync_ports.follow_camera) == "function") then
    return
  end

  local current_id = _resolve_follow_player_id(game)
  if current_id == nil then
    return
  end

  ui_sync_ports.follow_camera(state, current_id)
end

return turn_camera_policy
