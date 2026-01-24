local Tile = {}
Tile.__index = Tile

function Tile.from_config(cfg)
  local t = {
    id = cfg.id,
    name = cfg.name,
    type = cfg.type,
    price = cfg.price or 0,
    upgrade_costs = cfg.upgrade_costs or {},
    rents = cfg.rents or {},
    row = cfg.row,
    col = cfg.col,
    build_row = cfg.build_row,
    build_col = cfg.build_col,
  }
  return setmetatable(t, Tile)
end

function Tile.get_state(game, tile)
  assert(game and game.store, "Tile.get_state requires game.store")
  assert(tile and tile.type == "land", "Tile.get_state requires land tile")

  local s = game.store:get({ "board", "tiles", tile.id })
  assert(type(s) == "table", "missing tile state for tile " .. tostring(tile.id))

  return { owner_id = s.owner_id, level = s.level }
end

return Tile