local property = require("spec.support.property")
local pricing = require("src.rules.land.pricing")

-- Generate a land tile with a non-negative purchase price and an upgrade-cost
-- ladder of 0..5 non-negative entries. Non-negative costs/price are what make
-- the monotonicity properties hold; the ladder length (possibly 0) drives the
-- max-level clamp.
local function _gen_tile(rng)
  local ladder = {}
  for _ = 1, rng:int(0, 5) do
    ladder[#ladder + 1] = rng:int(0, 1000)
  end
  return { price = rng:int(0, 5000), upgrade_costs = ladder }
end

describe("pricing.total_invested properties", function()
  it("equals the purchase price at level 0 and at any non-positive level", function()
    property.for_all(_gen_tile, function(tile, rng)
      assert(pricing.total_invested(tile, 0) == tile.price,
        "level 0 invests exactly the purchase price")
      local below = rng:int(-5, 0)
      assert(pricing.total_invested(tile, below) == tile.price,
        "a non-positive level clamps to 0 -> purchase price only")
    end)
  end)

  it("is non-decreasing as the level rises", function()
    property.for_all(_gen_tile, function(tile)
      local previous = pricing.total_invested(tile, 0)
      for level = 1, #tile.upgrade_costs + 2 do
        local current = pricing.total_invested(tile, level)
        assert(current >= previous,
          "non-negative ladder costs make total_invested non-decreasing in level")
        previous = current
      end
    end)
  end)

  it("plateaus at and beyond the max level", function()
    property.for_all(_gen_tile, function(tile, rng)
      local max_level = #tile.upgrade_costs
      local at_max = pricing.total_invested(tile, max_level)
      local beyond = pricing.total_invested(tile, max_level + rng:int(1, 5))
      assert(beyond == at_max,
        "levels past the ladder length clamp to max -> same invested value")
    end)
  end)

  it("rises by exactly that level's upgrade cost on each unit step", function()
    property.for_all(_gen_tile, function(tile)
      -- The k-th step (level k-1 -> k) must add upgrade_costs[k], which is also
      -- what upgrade_cost(tile, k-1) reports: ties the two functions together.
      for k = 1, #tile.upgrade_costs do
        local step = pricing.total_invested(tile, k) - pricing.total_invested(tile, k - 1)
        assert(step == pricing.upgrade_cost(tile, k - 1),
          "step from level k-1 to k must equal upgrade_cost(tile, k-1)")
      end
    end)
  end)

  it("stays at the purchase price for any level when there is no upgrade ladder", function()
    property.for_all(function(rng)
      return { price = rng:int(0, 5000) }
    end, function(tile, rng)
      assert(pricing.total_invested(tile, rng:int(-3, 10)) == tile.price,
        "a tile with no upgrade_costs table never invests beyond its price")
    end)
  end)
end)

describe("pricing.rent_for_level properties", function()
  it("is non-decreasing as the level rises", function()
    property.for_all(_gen_tile, function(tile)
      local previous = pricing.rent_for_level(tile, 0)
      for level = 1, #tile.upgrade_costs + 2 do
        local current = pricing.rent_for_level(tile, level)
        assert(current >= previous, "rent must not drop as the level rises")
        previous = current
      end
    end)
  end)

  it("doubles between consecutive levels at and above level 1", function()
    property.for_all(_gen_tile, function(tile)
      -- For 1 <= L <= max_level the priced rent is exactly price * 2^(L-1)
      -- (the * 0.5 cancels a power of two with no fractional remainder), so
      -- each step up doubles the rent.
      local max_level = #tile.upgrade_costs
      for level = 1, max_level - 1 do
        local lower = pricing.rent_for_level(tile, level)
        local higher = pricing.rent_for_level(tile, level + 1)
        assert(higher == lower * 2,
          "rent doubles for each level step at or above level 1")
      end
    end)
  end)

  it("plateaus at and beyond the max level", function()
    property.for_all(_gen_tile, function(tile, rng)
      local max_level = #tile.upgrade_costs
      local at_max = pricing.rent_for_level(tile, max_level)
      local beyond = pricing.rent_for_level(tile, max_level + rng:int(1, 5))
      assert(beyond == at_max, "rent clamps to the max-level value beyond the ladder")
    end)
  end)

  it("falls back to the rents ladder when the tile has no price", function()
    property.for_all(function(rng)
      local rents = {}
      for _ = 1, rng:int(1, 5) do
        rents[#rents + 1] = rng:int(0, 9000)
      end
      return { rents = rents }
    end, function(tile, rng)
      local level = rng:int(0, #tile.rents - 1)
      assert(pricing.rent_for_level(tile, level) == tile.rents[level + 1],
        "an unpriced tile reads the rents ladder directly")
      assert(pricing.rent_for_level(tile, #tile.rents + rng:int(1, 3)) == 0,
        "an out-of-range rents lookup yields 0")
    end)
  end)
end)

describe("pricing.upgrade_cost / max_level properties", function()
  it("reports max level as the ladder length", function()
    property.for_all(_gen_tile, function(tile)
      assert(pricing.max_level(tile) == #tile.upgrade_costs,
        "max_level is the number of upgrade-cost entries")
    end)
    property.for_all(function(rng)
      return { price = rng:int(0, 5000) }
    end, function(tile)
      assert(pricing.max_level(tile) == 0, "no ladder means max_level 0")
    end)
  end)

  it("returns the ladder entry in range and 0 out of range", function()
    property.for_all(_gen_tile, function(tile, rng)
      for level = 0, #tile.upgrade_costs - 1 do
        assert(pricing.upgrade_cost(tile, level) == tile.upgrade_costs[level + 1],
          "an in-range level reads its ladder entry")
      end
      assert(pricing.upgrade_cost(tile, #tile.upgrade_costs + rng:int(0, 3)) == 0,
        "a level at or past the ladder length costs 0")
      assert(pricing.upgrade_cost(tile, -rng:int(1, 3)) == 0,
        "a negative level costs 0")
    end)
  end)
end)
