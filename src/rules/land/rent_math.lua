local rent_math = {}

local function _validate_contiguous_args(start_tile_id, owner_id, neighbors_by_id, resolve_owner_and_rent)
  assert(start_tile_id ~= nil, "missing start_tile_id")
  assert(owner_id ~= nil, "missing owner_id")
  assert(neighbors_by_id ~= nil, "missing neighbors_by_id")
  assert(resolve_owner_and_rent ~= nil, "missing resolve_owner_and_rent")
end

local function _enqueue_unvisited(queue, visited, neighbors)
  for _, next_id in ipairs(neighbors) do
    if not visited[next_id] then
      visited[next_id] = true
      queue[#queue + 1] = next_id
    end
  end
end

function rent_math.compute_contiguous_rent(start_tile_id, owner_id, neighbors_by_id, resolve_owner_and_rent)
  _validate_contiguous_args(start_tile_id, owner_id, neighbors_by_id, resolve_owner_and_rent)

  local rent_sum = 0
  local visited = { [start_tile_id] = true }
  local queue = { start_tile_id }
  local head = 1
  local component = {}
  local rents = {}

  while head <= #queue do
    local tile_id = queue[head]
    head = head + 1

    local current_owner, current_rent = resolve_owner_and_rent(tile_id)
    if current_owner == owner_id then
      local r = current_rent or 0
      component[#component + 1] = tile_id
      rents[#rents + 1] = r
      rent_sum = rent_sum + r
      local neighbors = neighbors_by_id[tile_id]
      assert(neighbors ~= nil, "missing neighbors: " .. tostring(tile_id))
      _enqueue_unvisited(queue, visited, neighbors)
    end
  end

  return rent_sum, component, rents
end

return rent_math

--[[ mutate4lua-manifest
version=2
projectHash=b0e6ed1b7011345e
scope.0.id=chunk:src/rules/land/rent_math.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=41
scope.0.semanticHash=5a97e3ad8a911d1f
]]
