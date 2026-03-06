local support = require("TestSupport")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local gameplay_read_port = require("src.presentation.read_model.GameplayReadPort")
local land_pricing = require("src.game.systems.land.LandPricing")

local function _test_total_land_invested_matches_domain_pricing()
  local tile = {
    price = 300,
    upgrade_costs = { 100, 150, 220 },
    rents = { 30, 80, 160, 300 },
  }
  local levels = { -1, 0, 1, 2, 3, 4, 7 }
  for _, level in ipairs(levels) do
    local expected = land_pricing.total_invested(tile, level)
    local actual = gameplay_read_port.total_land_invested(tile, level)
    _assert_eq(actual, expected, "read model total_invested must match domain pricing at level " .. tostring(level))
  end
end

local function _test_total_land_invested_handles_missing_costs_like_domain()
  local tile = { price = 500 }
  _assert_eq(gameplay_read_port.total_land_invested(tile, 3), land_pricing.total_invested(tile, 3),
    "read model should match domain when upgrade_costs missing")
end

local function _test_total_land_invested_caps_by_upgrade_cost_length()
  local tile = {
    price = 100,
    upgrade_costs = { 10, 20 },
  }
  _assert_eq(gameplay_read_port.total_land_invested(tile, 8), 130,
    "read model should cap invested total by available upgrade_costs")
  _assert_eq(land_pricing.total_invested(tile, 8), 130,
    "domain pricing should keep the same cap behavior")
end

local function _test_total_land_invested_handles_sparse_upgrade_cost_entries()
  local tile = {
    price = 200,
    upgrade_costs = { 10, nil, 40 },
  }
  _assert_eq(gameplay_read_port.total_land_invested(tile, 3), land_pricing.total_invested(tile, 3),
    "read model should match domain for sparse upgrade costs")
end

return {
  name = "read_model_contract",
  tests = {
    { name = "total_land_invested_matches_domain_pricing", run = _test_total_land_invested_matches_domain_pricing },
    { name = "total_land_invested_handles_missing_costs_like_domain", run = _test_total_land_invested_handles_missing_costs_like_domain },
    { name = "total_land_invested_caps_by_upgrade_cost_length", run = _test_total_land_invested_caps_by_upgrade_cost_length },
    { name = "total_land_invested_handles_sparse_upgrade_cost_entries", run = _test_total_land_invested_handles_sparse_upgrade_cost_entries },
  },
}
