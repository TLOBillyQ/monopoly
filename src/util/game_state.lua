local GameState = {}

function GameState.tile_state(game, tile)
  assert(game and game.store, "tile_state requires game.store")
  assert(tile and tile.type == "land", "tile_state requires land tile")

  local s = game.store:get({ "board", "tiles", tile.id })
  assert(type(s) == "table", "missing tile state for tile " .. tostring(tile.id))

  return { owner_id = s.owner_id, level = s.level }
end

return GameState
