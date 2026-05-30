local property_query = require("src.rules.board.property_query")
local pricing = require("src.rules.land.pricing")
local rent_math = require("src.rules.land.rent_math")

local resolver = {}

local function _ensure_land_neighbors(board)
  if board.land_neighbors then
    return board.land_neighbors
  end

  assert(board.map ~= nil and board.map.neighbors ~= nil, "missing board.map.neighbors")
  local neighbors = board.map.neighbors
  local land_neighbors = {}
  for _, tile in ipairs(board.path or {}) do
    if tile and tile.type == "land" then
      local neigh = neighbors[tile.id]
      assert(neigh ~= nil, "missing neighbors: " .. tostring(tile.id))
      local list = {}
      for _, next_id in pairs(neigh) do
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

local function _get_owner_cache(game, owner_id)
  local version = game._land_rent_version or 0
  local cache = game._land_rent_cache
  if not cache or cache.version ~= version then
    cache = {
      version = version,
      by_owner = {},
    }
    game._land_rent_cache = cache
  end

  local owner_cache = cache.by_owner[owner_id]
  if not owner_cache then
    owner_cache = { tile_sum = {}, tile_count = {}, tile_rents = {} }
    cache.by_owner[owner_id] = owner_cache
  end
  if not owner_cache.tile_count then
    owner_cache.tile_count = {}
  end
  if not owner_cache.tile_rents then
    owner_cache.tile_rents = {}
  end
  return owner_cache
end

resolver.safe_tile_state = property_query.safe_tile_state
resolver.resolve_rent_owner = property_query.resolve_rent_owner

local function _resolve_component(game, board, index, owner_id)
  assert(board ~= nil, "missing board")
  assert(board.map ~= nil, "missing board.map")
  local land_neighbors = _ensure_land_neighbors(board)

  local start_tile = assert(board:get_tile(index), "missing start tile: " .. tostring(index))
  assert(start_tile.type == "land", "invalid start tile: " .. tostring(index))
  local start_state = resolver.safe_tile_state(game, start_tile)
  if start_state.owner_id ~= owner_id then
    return start_tile, 0, 0, nil
  end

  local owner_cache = _get_owner_cache(game, owner_id)
  local cached_sum = owner_cache.tile_sum[start_tile.id]
  local cached_count = owner_cache.tile_count[start_tile.id]
  local cached_rents = owner_cache.tile_rents[start_tile.id]
  if cached_sum and cached_count then
    return start_tile, cached_sum, cached_count, nil, cached_rents
  end

  local rent_sum, component, rents = rent_math.compute_contiguous_rent(
    start_tile.id,
    owner_id,
    land_neighbors,
    function(tile_id)
      local tile = board:get_tile_by_id(tile_id)
      assert(tile ~= nil, "missing tile: " .. tostring(tile_id))
      if tile.type ~= "land" then
        return nil, 0
      end

      local state = resolver.safe_tile_state(game, tile)
      return state.owner_id, pricing.rent_for_level(tile, state.level or 0)
    end
  )

  local count = component and #component or 0
  for _, tile_id in ipairs(component or {}) do
    owner_cache.tile_sum[tile_id] = rent_sum
    owner_cache.tile_count[tile_id] = count
    owner_cache.tile_rents[tile_id] = rents
  end
  return start_tile, rent_sum, count, component, rents
end

function resolver.contiguous_rent(game, board, index, owner_id)
  local _, rent_sum = _resolve_component(game, board, index, owner_id)
  return rent_sum
end

function resolver.contiguous_count(game, board, index, owner_id)
  local _, _, count = _resolve_component(game, board, index, owner_id)
  return count
end

function resolver.contiguous_breakdown(game, board, index, owner_id)
  local start_tile, rent_sum, count, _, rents = _resolve_component(game, board, index, owner_id)
  if count == 0 then
    return { count = 0, single_rent = 0, total_rent = 0, rents = {} }
  end
  local start_state = resolver.safe_tile_state(game, start_tile)
  local single_rent = pricing.rent_for_level(start_tile, start_state.level or 0)
  return {
    count = count,
    single_rent = single_rent,
    total_rent = rent_sum,
    rents = rents or {},
  }
end

return resolver

--[[ mutate4lua-manifest
version=2
projectHash=3e911e942e378d02
scope.0.id=chunk:src/rules/land/rent_resolver.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=133
scope.0.semanticHash=4f5265d882fd3235
scope.1.id=function:_get_owner_cache:34
scope.1.kind=function
scope.1.startLine=34
scope.1.endLine=57
scope.1.semanticHash=1d7112acd81ece5b
scope.2.id=function:anonymous@86:86
scope.2.kind=function
scope.2.startLine=86
scope.2.endLine=95
scope.2.semanticHash=3cf4cc80740d1868
scope.3.id=function:resolver.contiguous_rent:107
scope.3.kind=function
scope.3.startLine=107
scope.3.endLine=110
scope.3.semanticHash=b36877d996b96bbc
scope.4.id=function:resolver.contiguous_count:112
scope.4.kind=function
scope.4.startLine=112
scope.4.endLine=115
scope.4.semanticHash=4263511bc89e7bd3
scope.5.id=function:resolver.contiguous_breakdown:117
scope.5.kind=function
scope.5.startLine=117
scope.5.endLine=130
scope.5.semanticHash=b6aabda244edeed7
]]
