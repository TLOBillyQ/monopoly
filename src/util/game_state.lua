local GameState = {}

function GameState.tile_state(game, tile)
  if not game or not game.store or not tile or tile.type ~= "land" then
    return { owner_id = nil, level = 0 }
  end
  local s = game.store:get({ "board", "tiles", tile.id })
  if type(s) ~= "table" then
    return { owner_id = nil, level = 0 }
  end
  return { owner_id = s.owner_id, level = s.level or 0 }
end

return GameState
