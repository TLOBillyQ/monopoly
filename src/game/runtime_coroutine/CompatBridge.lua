local compat_bridge = {}

function compat_bridge.sync_to_legacy_turn(game, snapshot)
  if type(game) ~= "table" or type(game.turn) ~= "table" then
    return
  end
  if type(snapshot) ~= "table" then
    return
  end
  if snapshot.wait_state then
    game.turn.phase = snapshot.wait_state
    return
  end
  if snapshot.current_state then
    game.turn.phase = snapshot.current_state
  end
end

return compat_bridge
