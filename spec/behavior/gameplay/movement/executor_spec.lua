local ring_map_builder = require("src.config.content.maps.ring_map_builder")

describe("movement_executor", function()
  it("_test_merge_executor_groups_combines_multiple_groups", function()
    local executors = require("src.rules.land.executors")
    local merged = executors._merge_executor_groups({
      { buy_land = { name = "buy" }, upgrade_land = { name = "upgrade" } },
      { pay_rent = { name = "rent" }, tax = { name = "tax" } },
    })
    assert(merged.buy_land ~= nil, "should have buy_land executor")
    assert(merged.upgrade_land ~= nil, "should have upgrade_land executor")
    assert(merged.pay_rent ~= nil, "should have pay_rent executor")
    assert(merged.tax ~= nil, "should have tax executor")
  end)

  it("_test_merge_executor_groups_later_overrides_earlier", function()
    local executors = require("src.rules.land.executors")
    local merged = executors._merge_executor_groups({
      { buy_land = { name = "original" } },
      { buy_land = { name = "override" } },
    })
    assert(merged.buy_land.name == "override", "later group should override earlier")
  end)

  it("_test_merge_executor_groups_handles_empty_groups", function()
    local executors = require("src.rules.land.executors")
    local merged = executors._merge_executor_groups({
      {},
      { buy_land = { name = "buy" } },
      {},
    })
    assert(merged.buy_land ~= nil, "should handle empty groups")
    assert(merged.buy_land.name == "buy", "should have correct executor after empty groups")
  end)

  it("_test_ring_map_direction_handles_next_prev_and_wraparound", function()
    local map = ring_map_builder.build({
      tile_ids = { 11, 12, 13, 14 },
      start_id = 11,
      market_id = 13,
    })

    assert(map.direction(11, 12) == "right", "ring map should mark next tile as right")
    assert(map.direction(12, 11) == "left", "ring map should mark previous tile as left")
    assert(map.direction(14, 11) == "right", "ring map should wrap last->first as right")
    assert(map.direction(11, 14) == "left", "ring map should wrap first->last as left")
  end)

  it("_test_ring_map_direction_rejects_missing_ids_and_non_adjacent_jump", function()
    local map = ring_map_builder.build({
      tile_ids = { 21, 22, 23, 24 },
      start_id = 21,
      market_id = 23,
    })

    local ok_missing_from, err_missing_from = pcall(function()
      return map.direction(999, 22)
    end)
    assert(ok_missing_from == false, "ring map should reject missing from_id")
    assert(type(err_missing_from) == "string" and string.find(err_missing_from, "missing from_id", 1, true),
      "ring map should explain missing from_id")

    local ok_nil_from, err_nil_from = pcall(function()
      return map.direction(nil, 22)
    end)
    assert(ok_nil_from == false, "ring map should reject nil from_id")
    assert(type(err_nil_from) == "string" and string.find(err_nil_from, "missing from_id", 1, true),
      "ring map should explain nil from_id")

    local ok_missing_to, err_missing_to = pcall(function()
      return map.direction(21, 999)
    end)
    assert(ok_missing_to == false, "ring map should reject missing to_id")
    assert(type(err_missing_to) == "string" and string.find(err_missing_to, "missing to_id", 1, true),
      "ring map should explain missing to_id")

    local ok_nil_to, err_nil_to = pcall(function()
      return map.direction(21, nil)
    end)
    assert(ok_nil_to == false, "ring map should reject nil to_id")
    assert(type(err_nil_to) == "string" and string.find(err_nil_to, "missing to_id", 1, true),
      "ring map should explain nil to_id")

    local ok_invalid_jump, err_invalid_jump = pcall(function()
      return map.direction(21, 23)
    end)
    assert(ok_invalid_jump == false, "ring map should reject non-adjacent jump")
    assert(type(err_invalid_jump) == "string" and string.find(err_invalid_jump, "invalid direction in ring map", 1, true),
      "ring map should explain invalid non-adjacent jump")
  end)
end)
