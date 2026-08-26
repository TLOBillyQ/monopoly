-- board.land_neighbors 的唯一所有者：由 board.map.neighbors 投影出的「只含 land」邻接表。
--
-- 这个缓存槽同时被 src/rules/land/rent_resolver（同色连片租金）和
-- src/ui/view/contiguous_count（连片数视图）读取。两边各自懒构建时,谁先跑谁写,
-- 另一边直接复用对方的结果——不变量被推导了两次却没有主人。此处收敛为单一构建者,
-- 于是「键和值都只是 land 地块 id」这条不变量只有一个落点。
--
-- 依赖方向：state 是内层,rules 与 ui 都可以向内依赖它,因此 ui 无需 require rules
-- 即可共享同一份投影(ui_no_rules 仍然成立)。
--
-- board 以 read seam 的形式鸭子类型传入,只要求 path / map.neighbors / get_tile_by_id。

local land_adjacency = {}

local function _land_neighbor_ids(board, neighbors, tile_id)
  local list = {}
  for _, next_id in pairs(neighbors[tile_id] or {}) do
    local next_tile = board:get_tile_by_id(next_id)
    if next_tile and next_tile.type == "land" then
      list[#list + 1] = next_id
    end
  end
  return list
end

local function _build(board, neighbors)
  local land_neighbors = {}
  for _, tile in ipairs(board.path or {}) do
    if tile and tile.type == "land" then
      land_neighbors[tile.id] = _land_neighbor_ids(board, neighbors, tile.id)
    end
  end
  board.land_neighbors = land_neighbors
  return land_neighbors
end

---视图接缝用：board 可能是不含 map 的局部投影,此时退化为空邻接表。
function land_adjacency.ensure(board)
  if board.land_neighbors then
    return board.land_neighbors
  end
  local neighbors = board.map and board.map.neighbors
  if neighbors == nil then
    return {}
  end
  return _build(board, neighbors)
end

local function _is_land(tile)
  return tile and tile.type == "land"
end

---缺 map.neighbors 或缺某块 land 的邻居即刻失败,返回校验通过的邻接源表。
local function _require_complete_neighbors(board)
  assert(board.map ~= nil and board.map.neighbors ~= nil, "missing board.map.neighbors")
  local neighbors = board.map.neighbors
  for _, tile in ipairs(board.path or {}) do
    if _is_land(tile) then
      assert(neighbors[tile.id] ~= nil, "missing neighbors: " .. tostring(tile.id))
    end
  end
  return neighbors
end

---领域用：额外要求棋盘是完整的。
---前置检查只在缓存冷启时跑一次,命中缓存的调用不付代价。
function land_adjacency.ensure_complete(board)
  if board.land_neighbors then
    return board.land_neighbors
  end
  return _build(board, _require_complete_neighbors(board))
end

return land_adjacency

--[[ mutate4lua-manifest
version=4
projectHash=f45a5ff18beaef74
scope.0.id=chunk:src/state/land_adjacency.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=75
scope.0.semanticHash=13c92163690aea1d
scope.1.id=function:_land_neighbor_ids
scope.1.kind=function
scope.1.startLine=15
scope.1.endLine=24
scope.1.semanticHash=c9a35eb122a28ae5
scope.2.id=function:_build
scope.2.kind=function
scope.2.startLine=26
scope.2.endLine=35
scope.2.semanticHash=1ab2fd59e1c91d4f
scope.3.id=function:land_adjacency.ensure
scope.3.kind=function
scope.3.startLine=38
scope.3.endLine=47
scope.3.semanticHash=1a5bc0201f30ccc7
scope.4.id=function:_is_land
scope.4.kind=function
scope.4.startLine=49
scope.4.endLine=51
scope.4.semanticHash=0d43a473e032cea8
scope.5.id=function:_require_complete_neighbors
scope.5.kind=function
scope.5.startLine=54
scope.5.endLine=63
scope.5.semanticHash=260d8f20bd4a89d4
scope.6.id=function:land_adjacency.ensure_complete
scope.6.kind=function
scope.6.startLine=67
scope.6.endLine=72
scope.6.semanticHash=49ee0ea7a30139d2
]]
