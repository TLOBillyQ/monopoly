local turn_camera_policy = {}

function turn_camera_policy.sync_follow(game, state, ports, ui_refreshed)
  if ui_refreshed ~= true then
    return
  end

  local ui_sync_ports = ports and ports.ui_sync or nil
  if not (ui_sync_ports and type(ui_sync_ports.follow_camera) == "function") then
    return
  end

  local turn = game and game.turn or nil
  local current_index = turn and turn.current_player_index or nil
  local current = current_index and game and game.players and game.players[current_index] or nil
  local current_id = current and current.id or nil
  if current_id == nil then
    return
  end

  ui_sync_ports.follow_camera(state, current_id)
end

return turn_camera_policy
