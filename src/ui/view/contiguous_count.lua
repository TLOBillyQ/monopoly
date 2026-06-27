-- View-layer BFS for same-owner land components. The gameplay equivalent lives
-- in src.rules.land.rent_math; this copy keeps src/ui from importing src/rules.
-- Inputs come exclusively from board state (read seam) so no domain knowledge is
-- required here.

local M = {}

-- Land-only adjacency for one tile: keep only neighbours that resolve to a land
-- tile via the board seam. Splitting this off keeps _ensure_land_neighbors a
-- pure cache/guard wrapper around the per-tile transform.
local function _land_neighbor_ids(board, tile_id, neighbors)
  local list = {}
  for _, next_id in pairs(neighbors[tile_id] or {}) do
    local next_tile = board:get_tile_by_id(next_id)
    if next_tile and next_tile.type == "land" then
      list[#list + 1] = next_id
    end
  end
  return list
end

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
      land_neighbors[tile.id] = _land_neighbor_ids(board, tile.id, neighbors)
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

local function _bfs_component(neighbors, board, start_tile_id, owner_id)
  local visited = { [start_tile_id] = true }
  local queue = { start_tile_id }
  local head = 1
  local component = {}
  while head <= #queue do
    local cur = queue[head]
    head = head + 1
    if _owner_of(board, cur) == owner_id then
      component[#component + 1] = cur
      for _, next_id in ipairs(neighbors[cur] or {}) do
        if not visited[next_id] then
          visited[next_id] = true
          queue[#queue + 1] = next_id
        end
      end
    end
  end
  return component
end

function M.for_tile(board, tile_id, owner_id)
  if not (board and tile_id ~= nil and owner_id ~= nil) then
    return 0
  end
  if _owner_of(board, tile_id) ~= owner_id then
    return 0
  end
  local neighbors = _ensure_land_neighbors(board)
  return #_bfs_component(neighbors, board, tile_id, owner_id)
end

-- Build a tile_id -> count map for every land tile owned by owner_id.
-- One BFS per connected component (vs one per tile when calling for_tile in a loop).
function M.build_for_owner(board, owner_id)
  local out = {}
  if not (board and owner_id ~= nil) then
    return out
  end
  local lookup = board.tile_lookup or {}
  local neighbors = _ensure_land_neighbors(board)
  for tile_id, tile in pairs(lookup) do
    if tile and tile.type == "land" and tile.owner_id == owner_id and out[tile_id] == nil then
      local component = _bfs_component(neighbors, board, tile_id, owner_id)
      local count = #component
      for _, cid in ipairs(component) do
        out[cid] = count
      end
    end
  end
  return out
end

function M.build_rent_for_owner(board, owner_id, rent_for_tile)
  local out = {}
  if not (board and owner_id ~= nil and type(rent_for_tile) == "function") then
    return out
  end
  local lookup = board.tile_lookup or {}
  local neighbors = _ensure_land_neighbors(board)
  for tile_id, tile in pairs(lookup) do
    if tile and tile.type == "land" and tile.owner_id == owner_id and out[tile_id] == nil then
      local component = _bfs_component(neighbors, board, tile_id, owner_id)
      local rent_sum = 0
      for _, cid in ipairs(component) do
        local component_tile = lookup[cid] or (type(board.get_tile_by_id) == "function" and board:get_tile_by_id(cid) or nil)
        rent_sum = rent_sum + (rent_for_tile(component_tile, cid) or 0)
      end
      for _, cid in ipairs(component) do
        out[cid] = rent_sum
      end
    end
  end
  return out
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=57d8c15d2145e8ae
scope.0.id=chunk:src/ui/view/contiguous_count.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=105
scope.0.semanticHash=ed65c61d676a471a
scope.1.id=function:_owner_of:40
scope.1.kind=function
scope.1.startLine=40
scope.1.endLine=49
scope.1.semanticHash=65e65e5a0a49b5bf
scope.2.id=function:M.for_tile:72
scope.2.kind=function
scope.2.startLine=72
scope.2.endLine=81
scope.2.semanticHash=38c5a4c82e390372
]]
