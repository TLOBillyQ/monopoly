local WorldOps = {}

function WorldOps.destroy_building(game, tile)
  if not tile or tile.type ~= "land" then
    return
  end
  if game and game.set_tile_level then
    game:set_tile_level(tile, 0)
  elseif game and game.store and tile and tile.id then
    game.store:set({ "board", "tiles", tile.id, "level" }, 0)
  end
end

function WorldOps.clear_overlays(game, idx)
  if not game or not game.overlays then
    return
  end
  if game.overlays.roadblocks and game.overlays.roadblocks[idx] then
    game.overlays.roadblocks[idx] = nil
  end
  if game.overlays.mines and game.overlays.mines[idx] then
    game.overlays.mines[idx] = nil
  end
end

return WorldOps
