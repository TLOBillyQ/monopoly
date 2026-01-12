local Board = {}
Board.__index = Board

function Board.new(data)
  local tile_lookup = (data and data.tile_lookup) or {}
  local path = (data and data.path) or {}

  local index_by_id = {}
  for idx, tile in ipairs(path) do
    index_by_id[tile.id] = idx
  end

  local b = {
    path = path,
    tile_lookup = tile_lookup,
    branches = (data and data.branches) or {},
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
function Board:advance(index, steps, branch_parity)
  local length = self:length()
  local current = index
  local passed_start = 0
  for _ = 1, steps do
    local branch = self.branches[current]
    if branch and branch_parity then
      current = (branch_parity % 2 == 1) and branch.odd or branch.even
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
