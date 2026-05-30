---@diagnostic disable: need-check-nil

local property = require("spec.support.property")
local rent_math = require("src.rules.land.rent_math")

-- Build a random tile graph: ids 1..N, each tile owned by one of a small pool
-- (so contiguous same-owner clusters actually occur), carrying a non-negative
-- rent, with a random neighbour list drawn from the same id space. Every id has
-- a neighbour entry so the BFS never trips its missing-neighbours assertion.
local OWNER_POOL = { 1, 2, 3 }

local function _gen_graph(rng)
  local tile_count = rng:int(1, 12)
  local owners, rents, neighbors = {}, {}, {}
  for id = 1, tile_count do
    owners[id] = rng:pick(OWNER_POOL)
    rents[id] = rng:int(0, 500)
    local list = {}
    for _ = 1, rng:int(0, 3) do
      list[#list + 1] = rng:int(1, tile_count)
    end
    neighbors[id] = list
  end
  return {
    tile_count = tile_count,
    owner_id = rng:pick(OWNER_POOL),
    start_tile_id = rng:int(1, tile_count),
    owners = owners,
    rents = rents,
    neighbors = neighbors,
  }
end

local function _resolver_for(graph)
  return function(tile_id)
    return graph.owners[tile_id], graph.rents[tile_id]
  end
end

local function _compute(graph, neighbors)
  return rent_math.compute_contiguous_rent(
    graph.start_tile_id, graph.owner_id, neighbors or graph.neighbors, _resolver_for(graph))
end

local function _set(list)
  local seen = {}
  for _, value in ipairs(list) do
    seen[value] = true
  end
  return seen
end

describe("rent_math.compute_contiguous_rent properties", function()
  it("reports a sum equal to the per-tile rents it returns", function()
    property.for_all(_gen_graph, function(graph)
      local sum, component, rents = _compute(graph)
      assert(#component == #rents, "component and rents lists must stay aligned")
      local total = 0
      for _, rent in ipairs(rents) do
        total = total + rent
      end
      assert(sum == total, "the reported sum must equal the sum of the reported rents")
    end)
  end)

  it("only includes tiles owned by the queried owner", function()
    property.for_all(_gen_graph, function(graph)
      local _, component = _compute(graph)
      for _, tile_id in ipairs(component) do
        assert(graph.owners[tile_id] == graph.owner_id,
          "component tile " .. tostring(tile_id) .. " is not owned by the queried owner")
      end
    end)
  end)

  it("includes the start tile when owned and is empty otherwise", function()
    property.for_all(_gen_graph, function(graph)
      local sum, component = _compute(graph)
      if graph.owners[graph.start_tile_id] == graph.owner_id then
        assert(_set(component)[graph.start_tile_id] == true, "an owned start tile must appear in the component")
      else
        assert(#component == 0, "an unowned start tile must yield an empty component")
        assert(sum == 0, "an unowned start tile must yield zero rent")
      end
    end)
  end)

  it("is independent of neighbour ordering", function()
    property.for_all(_gen_graph, function(graph)
      local sum_forward, component_forward = _compute(graph)

      local reversed = {}
      for id, list in pairs(graph.neighbors) do
        local flipped = {}
        for index = #list, 1, -1 do
          flipped[#flipped + 1] = list[index]
        end
        reversed[id] = flipped
      end
      local sum_reverse, component_reverse = _compute(graph, reversed)

      assert(sum_forward == sum_reverse, "rent sum must not depend on neighbour ordering")
      assert(#component_forward == #component_reverse, "component size must not depend on neighbour ordering")
      local reverse_set = _set(component_reverse)
      for tile_id in pairs(_set(component_forward)) do
        assert(reverse_set[tile_id] == true, "component membership must not depend on neighbour ordering")
      end
    end)
  end)

  it("never reports a negative total for non-negative rents", function()
    property.for_all(_gen_graph, function(graph)
      local sum = _compute(graph)
      assert(sum >= 0, "non-negative rents cannot sum to a negative total")
    end)
  end)
end)
