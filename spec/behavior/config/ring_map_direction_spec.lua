local support = require("spec.support.shared_support")
local ring_map_builder = require("src.config.content.ring_map_builder")

local _assert_eq = support.assert_eq

describe("ring_map_direction_crap_coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("direction next returns right", function()
    local opts = {
      tile_ids = { "a", "b", "c" },
      start_id = "a",
      market_id = "b",
    }
    local map = ring_map_builder.build(opts)
    local result = map.direction("a", "b")
    _assert_eq(result, "right", "direction from a to b (next) should return right")
  end)

  it("direction prev returns left", function()
    local opts = {
      tile_ids = { "a", "b", "c" },
      start_id = "a",
      market_id = "b",
    }
    local map = ring_map_builder.build(opts)
    local result = map.direction("b", "a")
    _assert_eq(result, "left", "direction from b to a (prev, wraps) should return left")
  end)

  it("direction illegal jump asserts", function()
    local opts = {
      tile_ids = { "a", "b", "c", "d" },
      start_id = "a",
      market_id = "b",
    }
    local map = ring_map_builder.build(opts)
    local ok, err = pcall(function()
      map.direction("a", "c")
    end)
    _assert_eq(ok, false, "direction for non-adjacent tiles should assert")
    assert(err:match("invalid direction"), "error should mention invalid direction")
  end)

  it("direction missing from_id asserts", function()
    local opts = {
      tile_ids = { "a", "b", "c" },
      start_id = "a",
      market_id = "b",
    }
    local map = ring_map_builder.build(opts)
    local ok, err = pcall(function()
      map.direction("missing_id", "b")
    end)
    _assert_eq(ok, false, "direction with missing from_id should assert")
    assert(err:match("missing from_id"), "error should mention missing from_id")
  end)

  it("direction missing to_id asserts", function()
    local opts = {
      tile_ids = { "a", "b", "c" },
      start_id = "a",
      market_id = "b",
    }
    local map = ring_map_builder.build(opts)
    local ok, err = pcall(function()
      map.direction("a", "missing_id")
    end)
    _assert_eq(ok, false, "direction with missing to_id should assert")
    assert(err:match("missing to_id"), "error should mention missing to_id")
  end)
end)
