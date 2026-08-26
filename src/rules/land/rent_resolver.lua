local land_adjacency = require("src.state.land_adjacency")
local property_query = require("src.rules.board.property_query")
local pricing = require("src.rules.land.pricing")
local rent_math = require("src.rules.land.rent_math")

local resolver = {}

-- 版本号一变(买地/加盖改了租金基数)整张缓存作废。
local function _ensure_rent_cache(game)
  local version = game._land_rent_version or 0
  local cache = game._land_rent_cache
  if not cache or cache.version ~= version then
    cache = {
      version = version,
      by_owner = {},
    }
    game._land_rent_cache = cache
  end
  return cache
end

local function _ensure_owner_bucket(cache, owner_id)
  local owner_cache = cache.by_owner[owner_id]
  if not owner_cache then
    owner_cache = { tile_sum = {}, tile_count = {}, tile_rents = {} }
    cache.by_owner[owner_id] = owner_cache
  end
  return owner_cache
end

local function _get_owner_cache(game, owner_id)
  return _ensure_owner_bucket(_ensure_rent_cache(game), owner_id)
end

resolver.safe_tile_state = property_query.safe_tile_state
resolver.resolve_rent_owner = property_query.resolve_rent_owner

local function _compute_and_cache(game, board, land_neighbors, owner_cache, start_tile, owner_id)
  local rent_sum, component, rents = rent_math.compute_contiguous_rent(
    start_tile.id,
    owner_id,
    land_neighbors,
    function(tile_id)
      local tile = board:get_tile_by_id(tile_id)
      assert(tile ~= nil, "missing tile: " .. tostring(tile_id))
      if tile.type ~= "land" then
        return nil
      end

      local state = resolver.safe_tile_state(game, tile)
      return state.owner_id, pricing.rent_for_level(tile, state.level)
    end
  )

  -- rent_math 总是返回 component 表(至少含起始地块),无需 nil 兜底。
  local count = #component
  for _, tile_id in ipairs(component) do
    owner_cache.tile_sum[tile_id] = rent_sum
    owner_cache.tile_count[tile_id] = count
    owner_cache.tile_rents[tile_id] = rents
  end
  return rent_sum, count, component, rents
end

-- 棋盘完整性(map.neighbors 齐全)由 land_adjacency.ensure_complete 断言,这里只挡住 nil board。
local function _require_land_neighbors(board)
  assert(board ~= nil, "missing board")
  return land_adjacency.ensure_complete(board)
end

local function _require_land_start_tile(board, index)
  local start_tile = assert(board:get_tile(index), "missing start tile: " .. tostring(index))
  assert(start_tile.type == "land", "invalid start tile: " .. tostring(index))
  return start_tile
end

local function _resolve_component(game, board, index, owner_id)
  local land_neighbors = _require_land_neighbors(board)

  local start_tile = _require_land_start_tile(board, index)
  local start_state = resolver.safe_tile_state(game, start_tile)
  if start_state.owner_id ~= owner_id then
    return start_tile, 0, 0, nil
  end

  local owner_cache = _get_owner_cache(game, owner_id)
  -- tile_sum / tile_count / tile_rents 由 _compute_and_cache 在同一轮里写满,
  -- 三者要么同时在要么同时不在,因此只需探测其中一个。
  local cached_sum = owner_cache.tile_sum[start_tile.id]
  if cached_sum then
    return start_tile,
      cached_sum,
      owner_cache.tile_count[start_tile.id],
      nil,
      owner_cache.tile_rents[start_tile.id]
  end

  local rent_sum, count, component, rents =
    _compute_and_cache(game, board, land_neighbors, owner_cache, start_tile, owner_id)
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
  local single_rent = pricing.rent_for_level(start_tile, start_state.level)
  return {
    count = count,
    single_rent = single_rent,
    total_rent = rent_sum,
    rents = rents or {},
  }
end

return resolver

--[[ mutate4lua-manifest
version=4
projectHash=ab9b2ca4a8c28f1d
scope.0.id=chunk:src/rules/land/rent_resolver.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=129
scope.0.semanticHash=e7503a4d6df8fd66
scope.1.id=function:_ensure_rent_cache
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=20
scope.1.semanticHash=981206d65fceb63f
scope.2.id=function:_ensure_owner_bucket
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=29
scope.2.semanticHash=cc94b23f1a076eac
scope.3.id=function:_get_owner_cache
scope.3.kind=function
scope.3.startLine=31
scope.3.endLine=33
scope.3.semanticHash=f646e505d37549c9
scope.4.id=function:_compute_and_cache
scope.4.kind=function
scope.4.startLine=38
scope.4.endLine=63
scope.4.semanticHash=69b2ca0524283ed3
scope.5.id=function:<anonymous>
scope.5.kind=function
scope.5.startLine=43
scope.5.endLine=52
scope.5.semanticHash=814b1dbc1c65c317
scope.6.id=function:_require_land_neighbors
scope.6.kind=function
scope.6.startLine=66
scope.6.endLine=69
scope.6.semanticHash=aa3e8020dcbe5fbe
scope.7.id=function:_require_land_start_tile
scope.7.kind=function
scope.7.startLine=71
scope.7.endLine=75
scope.7.semanticHash=0ff871fe32768e81
scope.8.id=function:_resolve_component
scope.8.kind=function
scope.8.startLine=77
scope.8.endLine=101
scope.8.semanticHash=61dcf25c6b0c5c5a
scope.9.id=function:resolver.contiguous_rent
scope.9.kind=function
scope.9.startLine=103
scope.9.endLine=106
scope.9.semanticHash=7bb2fcbc0a40b7be
scope.10.id=function:resolver.contiguous_count
scope.10.kind=function
scope.10.startLine=108
scope.10.endLine=111
scope.10.semanticHash=3cdbec6da63a9b25
scope.11.id=function:resolver.contiguous_breakdown
scope.11.kind=function
scope.11.startLine=113
scope.11.endLine=126
scope.11.semanticHash=386cba03ba4fce3d
]]
