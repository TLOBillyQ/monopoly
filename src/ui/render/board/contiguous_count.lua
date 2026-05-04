-- View-layer BFS that counts how many same-owner land tiles are connected to a
-- starting tile. The gameplay equivalent lives in src.rules.land.rent_math; this
-- copy keeps src/ui from importing src/rules. Inputs come exclusively from board
-- state (read seam) so no domain knowledge is required here.

local M = {}

local function _ensure_land_neighbors(board)
  if board.land_neighbors then
    return board.land_neighbors
  end
  local neighbors = board.map and board.map.neighbors
  if neighbors == nil then
    return {}
  end
  local land_neighbors = {}
  for _, tile in ipairs(board.path or {}) do
    if tile and tile.type == "land" then
      local list = {}
      for _, next_id in pairs(neighbors[tile.id] or {}) do
        local next_tile = board:get_tile_by_id(next_id)
        if next_tile and next_tile.type == "land" then
          list[#list + 1] = next_id
        end
      end
      land_neighbors[tile.id] = list
    end
  end
  board.land_neighbors = land_neighbors
  return land_neighbors
end

local function _owner_of(board, tile_id)
  if board.tile_lookup and board.tile_lookup[tile_id] then
    return board.tile_lookup[tile_id].owner_id
  end
  if type(board.get_tile_by_id) == "function" then
    local tile = board:get_tile_by_id(tile_id)
    return tile and tile.owner_id or nil
  end
  return nil
end

function M.for_tile(board, tile_id, owner_id)
  if not (board and tile_id ~= nil and owner_id ~= nil) then
    return 0
  end
  if _owner_of(board, tile_id) ~= owner_id then
    return 0
  end
  local neighbors = _ensure_land_neighbors(board)
  local visited = { [tile_id] = true }
  local queue = { tile_id }
  local head = 1
  local count = 0
  while head <= #queue do
    local cur = queue[head]
    head = head + 1
    if _owner_of(board, cur) == owner_id then
      count = count + 1
      for _, next_id in ipairs(neighbors[cur] or {}) do
        if not visited[next_id] then
          visited[next_id] = true
          queue[#queue + 1] = next_id
        end
      end
    end
  end
  return count
end

return M
