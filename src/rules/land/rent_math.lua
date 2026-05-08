local rent_math = {}

function rent_math.compute_contiguous_rent(start_tile_id, owner_id, neighbors_by_id, resolve_owner_and_rent)
  assert(start_tile_id ~= nil, "missing start_tile_id")
  assert(owner_id ~= nil, "missing owner_id")
  assert(neighbors_by_id ~= nil, "missing neighbors_by_id")
  assert(resolve_owner_and_rent ~= nil, "missing resolve_owner_and_rent")

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
      for _, next_id in ipairs(neighbors) do
        if not visited[next_id] then
          visited[next_id] = true
          queue[#queue + 1] = next_id
        end
      end
    end
  end

  return rent_sum, component, rents
end

return rent_math
