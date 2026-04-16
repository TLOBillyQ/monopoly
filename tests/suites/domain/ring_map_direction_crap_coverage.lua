local support = require("support.domain_support")
local ring_map_builder = require("src.config.content.maps.ring_map_builder")

local _assert_eq = support.assert_eq

local function _test_direction_next_returns_right()
  local opts = {
    tile_ids = { "a", "b", "c" },
    start_id = "a",
    market_id = "b",
  }
  local map = ring_map_builder.build(opts)
  local result = map.direction("a", "b")
  _assert_eq(result, "right", "direction from a to b (next) should return right")
end

local function _test_direction_prev_returns_left()
  local opts = {
    tile_ids = { "a", "b", "c" },
    start_id = "a",
    market_id = "b",
  }
  local map = ring_map_builder.build(opts)
  local result = map.direction("b", "a")
  _assert_eq(result, "left", "direction from b to a (prev, wraps) should return left")
end

local function _test_direction_illegal_jump_asserts()
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
end

local function _test_direction_missing_from_id_asserts()
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
end

local function _test_direction_missing_to_id_asserts()
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
end

return {
  name = "ring_map_direction_crap_coverage",
  tests = {
    {
      name = "direction next returns right",
      run = _test_direction_next_returns_right,
    },
    {
      name = "direction prev returns left",
      run = _test_direction_prev_returns_left,
    },
    {
      name = "direction illegal jump asserts",
      run = _test_direction_illegal_jump_asserts,
    },
    {
      name = "direction missing from_id asserts",
      run = _test_direction_missing_from_id_asserts,
    },
    {
      name = "direction missing to_id asserts",
      run = _test_direction_missing_to_id_asserts,
    },
  },
}
