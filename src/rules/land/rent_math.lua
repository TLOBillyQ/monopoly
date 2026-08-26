-- 连片 BFS 本身住在 src.state.land_component（领域与视图共用同一条走法）；
-- 这里只负责租金语义：解析每块地的主人与租金,并把同主连片折叠成租金和。

local land_component = require("src.state.land_component")

local rent_math = {}

local function _validate_contiguous_args(start_tile_id, owner_id, neighbors_by_id, resolve_owner_and_rent)
  assert(start_tile_id ~= nil, "missing start_tile_id")
  assert(owner_id ~= nil, "missing owner_id")
  assert(neighbors_by_id ~= nil, "missing neighbors_by_id")
  assert(resolve_owner_and_rent ~= nil, "missing resolve_owner_and_rent")
end

-- 领域侧的邻接是完整的：走到哪块地都必须有邻居表,缺了就是棋盘数据坏了。
local function _strict_neighbors_of(neighbors_by_id)
  return function(tile_id)
    local neighbors = neighbors_by_id[tile_id]
    assert(neighbors ~= nil, "missing neighbors: " .. tostring(tile_id))
    return neighbors
  end
end

function rent_math.compute_contiguous_rent(start_tile_id, owner_id, neighbors_by_id, resolve_owner_and_rent)
  _validate_contiguous_args(start_tile_id, owner_id, neighbors_by_id, resolve_owner_and_rent)

  -- 每块地的租金在 BFS 判主时顺手记下,连片定下来后再按 component 顺序折叠。
  local rent_by_id = {}
  local component = land_component.same_owner(start_tile_id, owner_id, function(tile_id)
    local current_owner, current_rent = resolve_owner_and_rent(tile_id)
    rent_by_id[tile_id] = current_rent or 0
    return current_owner
  end, _strict_neighbors_of(neighbors_by_id))

  local rent_sum = 0
  local rents = {}
  for i, tile_id in ipairs(component) do
    rents[i] = rent_by_id[tile_id]
    rent_sum = rent_sum + rents[i]
  end

  return rent_sum, component, rents
end

return rent_math

--[[ mutate4lua-manifest
version=4
projectHash=aca40d19bfd2c170
scope.0.id=chunk:src/rules/land/rent_math.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=46
scope.0.semanticHash=c73624f4d2216fc5
scope.1.id=function:_validate_contiguous_args
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=13
scope.1.semanticHash=3f9891174805d4fe
scope.2.id=function:_strict_neighbors_of
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=22
scope.2.semanticHash=1f44c4af05edd8ef
scope.3.id=function:<anonymous>
scope.3.kind=function
scope.3.startLine=17
scope.3.endLine=21
scope.3.semanticHash=87fd4b2d101479ee
scope.4.id=function:rent_math.compute_contiguous_rent
scope.4.kind=function
scope.4.startLine=24
scope.4.endLine=43
scope.4.semanticHash=812d641e41164af3
scope.5.id=function:<anonymous>#2
scope.5.kind=function
scope.5.startLine=29
scope.5.endLine=33
scope.5.semanticHash=9e82ef68be915451
]]
