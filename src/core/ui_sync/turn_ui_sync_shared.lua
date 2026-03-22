local shared = {}

function shared.is_only_turn_countdown(dirty)
  if not dirty or dirty.turn_countdown ~= true then
    return false
  end
  if dirty.players or dirty.board_tiles or dirty.turn or dirty.market or dirty.ui then
    return false
  end
  if dirty.inventory_ids then
    for _ in pairs(dirty.inventory_ids) do
      return false
    end
  end
  return true
end

function shared.build_ui_env(state, game)
  local winner = game and game.winner or nil
  local winner_name = game and (game.winner_names or (winner and winner.name)) or nil
  return {
    game = game,
    ui_state = state,
    last_turn = game and game.last_turn or nil,
    finished = game and game.finished or nil,
    winner_name = winner_name,
  }
end

return shared
