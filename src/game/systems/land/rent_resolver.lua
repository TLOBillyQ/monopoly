local pricing = require("src.game.systems.land.pricing")
local rent_math = require("src.game.systems.land.rent_math")

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

local function _get_rent_cache(game, owner_id)
  local version = game._land_rent_version or 0
  local cache = game._land_rent_cache
  if not cache or cache.version ~= version then
    cache = { version = version, by_owner = {} }
    game._land_rent_cache = cache
  end
  local owner_cache = cache.by_owner[owner_id]
  if not owner_cache then
    owner_cache = { tile_sum = {} }
    cache.by_owner[owner_id] = owner_cache
  end
  return owner_cache.tile_sum
end

function resolver.safe_tile_state(game, tile)
  if not (game and tile and tile.type == "land") then
    return { owner_id = nil, level = 0 }
  end
  return { owner_id = tile.owner_id, level = tile.level or 0 }
end

function resolver.resolve_rent_owner(game, tile, state_fn)
  local st = resolver.safe_tile_state(game, tile)
  if state_fn then
    st = state_fn(game, tile)
  end
  local owner = nil
  if st.owner_id then
    owner = game:find_player_by_id(st.owner_id)
  end
  if not owner or owner.eliminated then
    game:set_tile_owner(tile, nil)
    return nil, st, nil
  end

  if game:player_is_in_mountain(owner) then
    return nil, st, { reason = "mountain", owner = owner }
  end
  return owner, st, nil
end

function resolver.contiguous_rent(game, board, index, owner_id)
  assert(board ~= nil, "missing board")
  assert(board.map ~= nil, "missing board.map")
  local land_neighbors = _ensure_land_neighbors(board)

  local start_tile = assert(board:get_tile(index), "missing start tile: " .. tostring(index))
  assert(start_tile.type == "land", "invalid start tile: " .. tostring(index))
  local start_state = resolver.safe_tile_state(game, start_tile)
  if start_state.owner_id ~= owner_id then
    return 0
  end

  local tile_sum = _get_rent_cache(game, owner_id)
  local cached = tile_sum[start_tile.id]
  if cached then
    return cached
  end

  local rent_sum, component = rent_math.compute_contiguous_rent(start_tile.id, owner_id, land_neighbors,
    function(tile_id)
    local tile = board:get_tile_by_id(tile_id)
    assert(tile ~= nil, "missing tile: " .. tostring(tile_id))
    if tile.type ~= "land" then
      return nil, 0
    end
    local st2 = resolver.safe_tile_state(game, tile)
    return st2.owner_id, pricing.rent_for_level(tile, st2.level or 0)
  end)

  for _, tile_id in ipairs(component) do
    tile_sum[tile_id] = rent_sum
  end
  return rent_sum
end

return resolver
