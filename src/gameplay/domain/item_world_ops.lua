local WorldOps = {}
local Services = require("src.util.services")

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
  if not game then
    return
  end
  local overlay = Services.overlay(game)
  if not overlay then
    return
  end
  overlay.clear_roadblock(game, idx)
  overlay.clear_mine(game, idx)
end

return WorldOps
