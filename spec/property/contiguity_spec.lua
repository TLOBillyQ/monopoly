local property = require("spec.support.property")
local contiguous_count = require("src.ui.view.contiguous_count")

-- Generate a random board: a path of land/non-land tiles with random owners and
-- a random symmetric adjacency graph. The board exposes both read seams that
-- contiguous_count understands (tile_lookup and get_tile_by_id) so the two
-- counting paths under test share identical inputs.
local OWNERS = { 10, 20, 30 }

local function _gen_board(rng)
  local n = rng:int(1, 10)
  local tiles, lookup = {}, {}
  for id = 1, n do
    local is_land = rng:int(1, 4) > 1 -- ~75% land, rest non-land neighbours
    local owner
    if is_land and rng:bool() then
      owner = rng:pick(OWNERS) -- some land stays unowned (owner nil)
    end
    local tile = { id = id, type = is_land and "land" or "market", owner_id = owner }
    tiles[id] = tile
    lookup[id] = tile
  end
  local neighbors = {}
  for id = 1, n do
    neighbors[id] = {}
  end
  for id = 1, n do
    for jd = id + 1, n do
      if rng:int(1, 3) == 1 then -- sparse random symmetric edges
        neighbors[id][#neighbors[id] + 1] = jd
        neighbors[jd][#neighbors[jd] + 1] = id
      end
    end
  end
  local board = { path = tiles, tile_lookup = lookup, map = { neighbors = neighbors } }
  function board:get_tile_by_id(tile_id)
    return lookup[tile_id]
  end
  return { board = board, tiles = tiles, neighbors = neighbors }
end

-- Independent oracle: connected-component size of `owner`'s land tiles over the
-- land-only adjacency graph, computed with a plain flood fill that shares no
-- code with contiguous_count's BFS.
local function _oracle_counts(case, owner)
  local tiles, neighbors = case.tiles, case.neighbors
  local function is_owned_land(id)
    local tile = tiles[id]
    return tile and tile.type == "land" and tile.owner_id == owner
  end
  local counts = {}
  for start_id in pairs(tiles) do
    if is_owned_land(start_id) and counts[start_id] == nil then
      local component, stack, seen = {}, { start_id }, { [start_id] = true }
      while #stack > 0 do
        local cur = stack[#stack]
        stack[#stack] = nil
        component[#component + 1] = cur
        for _, next_id in ipairs(neighbors[cur] or {}) do
          if not seen[next_id] and is_owned_land(next_id) and tiles[cur].type == "land" then
            seen[next_id] = true
            stack[#stack + 1] = next_id
          end
        end
      end
      for _, cid in ipairs(component) do
        counts[cid] = #component
      end
    end
  end
  return counts
end

describe("contiguous_count contiguity properties", function()
  it("for_tile agrees with build_for_owner for every land tile", function()
    property.for_all(_gen_board, function(case)
      for _, owner in ipairs(OWNERS) do
        local swept = contiguous_count.build_for_owner(case.board, owner)
        for id, tile in pairs(case.tiles) do
          local per_tile = contiguous_count.for_tile(case.board, id, owner)
          if tile.type == "land" and tile.owner_id == owner then
            assert(per_tile == swept[id],
              "for_tile must match build_for_owner for owned land tile " .. tostring(id)
              .. "; got " .. tostring(per_tile) .. " vs " .. tostring(swept[id]))
          else
            assert(per_tile == 0, "for_tile must be 0 for tile " .. tostring(id) .. " not owned by " .. tostring(owner))
            assert(swept[id] == nil, "build_for_owner must omit tile " .. tostring(id) .. " not owned by " .. tostring(owner))
          end
        end
      end
    end)
  end)

  it("both counting paths match an independent flood-fill oracle", function()
    property.for_all(_gen_board, function(case)
      for _, owner in ipairs(OWNERS) do
        local expected = _oracle_counts(case, owner)
        local swept = contiguous_count.build_for_owner(case.board, owner)
        for id in pairs(case.tiles) do
          assert(swept[id] == expected[id],
            "build_for_owner must match oracle for tile " .. tostring(id)
            .. "; got " .. tostring(swept[id]) .. " want " .. tostring(expected[id]))
          if expected[id] ~= nil then
            assert(contiguous_count.for_tile(case.board, id, owner) == expected[id],
              "for_tile must match oracle for tile " .. tostring(id))
          end
        end
      end
    end)
  end)

  it("is idempotent: repeated counts are stable once land neighbours are cached", function()
    property.for_all(_gen_board, function(case)
      for _, owner in ipairs(OWNERS) do
        local first = contiguous_count.build_for_owner(case.board, owner)
        -- The board now carries a cached land_neighbors map; a second sweep must
        -- read the cache (not rebuild) and return an identical result.
        assert(case.board.land_neighbors ~= nil, "build_for_owner should cache land_neighbors on the board")
        local second = contiguous_count.build_for_owner(case.board, owner)
        for id, count in pairs(first) do
          assert(second[id] == count, "cached sweep must repeat the first count for tile " .. tostring(id))
          assert(contiguous_count.for_tile(case.board, id, owner) == count,
            "for_tile over the cached board must match build_for_owner for tile " .. tostring(id))
          assert(count >= 1, "a counted tile must belong to a component of at least size 1")
        end
        for id in pairs(second) do
          assert(first[id] ~= nil, "cached sweep must not invent a tile absent from the first sweep")
        end
      end
    end)
  end)
end)
