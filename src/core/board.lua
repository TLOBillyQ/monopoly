local Tile = require("src.core.tile")
local tiles_config = require("src.config.tiles")
local map_config = require("src.config.map")

local Board = {}
Board.__index = Board

function Board.new()
  local tile_lookup = {}
  for _, cfg in ipairs(tiles_config) do
    tile_lookup[cfg.id] = Tile.from_config(cfg)
  end

  local path = {}
  for _, id in ipairs(map_config.path) do
    table.insert(path, tile_lookup[id])
  end

  local index_by_id = {}
  for idx, tile in ipairs(path) do
    index_by_id[tile.id] = idx
  end

  local b = {
    path = path,
    tile_lookup = tile_lookup,
    branches = map_config.branches or {},
    index_by_id = index_by_id,
  }
  return setmetatable(b, Board)
end

function Board:length()
  return #self.path
end

function Board:index_of_tile_id(id)
  return self.index_by_id[id]
end

function Board:get_tile(index)
  return self.path[index]
end

function Board:get_tile_by_id(id)
  return self.tile_lookup[id]
end

function Board:find_first_by_type(tile_type)
  for idx, tile in ipairs(self.path) do
    if tile.type == tile_type then
      return idx, tile
    end
  end
  return nil, nil
end

-- 计算下一步索引，支持分支（奇左偶右）
function Board:advance(index, steps, dice_total)
  local length = self:length()
  local current = index
  local passed_start = 0
  for _ = 1, steps do
    local branch = self.branches[current]
    if branch and dice_total then
      current = (dice_total % 2 == 1) and branch.odd or branch.even
    else
      current = current + 1
    end
    if current > length then
      current = current - length
      passed_start = passed_start + 1
    end
  end
  return current, passed_start
end

return Board
