local property_query = {}

function property_query.safe_tile_state(game, tile)
  if not (game and tile and tile.type == "land") then
    return { owner_id = nil, level = 0 }
  end
  return { owner_id = tile.owner_id, level = tile.level or 0 }
end

function property_query.resolve_rent_owner(game, tile, state_fn)
  local state = property_query.safe_tile_state(game, tile)
  if state_fn then
    state = state_fn(game, tile)
  end

  local owner = nil
  if state.owner_id then
    owner = game:find_player_by_id(state.owner_id)
  end
  if not owner or owner.eliminated then
    game:set_tile_owner(tile, nil)
    return nil, state, nil
  end
  if game:player_is_in_mountain(owner) then
    return nil, state, { reason = "mountain", owner = owner }
  end
  return owner, state, nil
end

return property_query

--[[ mutate4lua-manifest
version=2
projectHash=b33a501fa0512d67
scope.0.id=chunk:src/rules/board/property_query.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=31
scope.0.semanticHash=4910760cdd27724b
scope.1.id=function:property_query.safe_tile_state:3
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=8
scope.1.semanticHash=4d0eeece3e3b9052
scope.2.id=function:property_query.resolve_rent_owner:10
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=28
scope.2.semanticHash=f20a94c1cd1dfa5c
]]
