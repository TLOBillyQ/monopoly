local Board = require("src.gameplay.domain.core.board")
local Tile = require("src.gameplay.domain.core.tile")

local tiles_config = require("src.config.tiles")
local map_config = require("src.config.map")

local BoardFactory = {}

function BoardFactory.create(opts)
  opts = opts or {}
  local tiles = opts.tiles or tiles_config
  local map_cfg = opts.map or map_config

  local tile_lookup = {}
  for _, cfg in ipairs(tiles) do
    tile_lookup[cfg.id] = Tile.from_config(cfg)
  end

  local path = {}
  for _, id in ipairs(map_cfg.path) do
    table.insert(path, tile_lookup[id])
  end

  return Board.new({
    path = path,
    tile_lookup = tile_lookup,
    branches = map_cfg.branches or {},
  })
end

return BoardFactory
