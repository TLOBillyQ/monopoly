local luassert = assert
local gameplay_read_port = require("src.ui.view.gameplay_read_port")
local land_pricing = require("src.rules.land.pricing")

describe("TestReadModel", function()

it("test_total_land_invested_matches_domain_pricing_for_typical_levels", function()
  local tile = {
    price = 300,
    upgrade_costs = { 100, 150, 220 },
    rents = { 30, 80, 160, 300 },
  }
  local levels = { -1, 0, 1, 2, 3, 4, 7 }
  for _, level in ipairs(levels) do
    local expected = land_pricing.total_invested(tile, level)
    local actual = gameplay_read_port.total_land_invested(tile, level)
    luassert.is.equal(expected, actual, "read model total_invested must match domain pricing at level " .. tostring(level))
  end
end)

it("test_total_land_invested_handles_missing_upgrade_costs_like_domain", function()
  local tile = { price = 500 }
  luassert.is.equal(
    land_pricing.total_invested(tile, 3),
    gameplay_read_port.total_land_invested(tile, 3),
    "read model should match domain when upgrade_costs missing"
  )
end)

it("test_total_land_invested_caps_by_upgrade_cost_length", function()
  local tile = {
    price = 100,
    upgrade_costs = { 10, 20 },
  }
  luassert.is.equal(
    land_pricing.total_invested(tile, 8),
    gameplay_read_port.total_land_invested(tile, 8),
    "read model should cap invested total by available upgrade_costs"
  )
end)

it("test_total_land_invested_handles_sparse_upgrade_cost_entries", function()
  local tile = {
    price = 200,
    upgrade_costs = { 10, nil, 40 },
  }
  luassert.is.equal(
    land_pricing.total_invested(tile, 3),
    gameplay_read_port.total_land_invested(tile, 3),
    "read model should match domain for sparse upgrade costs"
  )
end)

end)
