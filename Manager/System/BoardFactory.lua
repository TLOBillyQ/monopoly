local Board = require("Components.Board")
local Tile = require("Components.Tile")

local tiles_config = require("Config.Tiles")
local map_config = require("Config.Map")

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
    map = map_cfg,
    overlays = { roadblocks = {}, mines = {} },
  })
end

return BoardFactory
