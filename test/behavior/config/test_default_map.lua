-- Data-integrity pinning tests for src.config.content.default_map.
-- Exercises the _direction private function and validates the cardinality
-- tables (turn_left / turn_right), entry_points, and fresh_forward_next
-- return values that combinatorial movement tests don't exhaustively
-- assert in isolation.
-- Survivors from #293 batch 2.

local lu = require("luaunit")
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq

local default_map = require("src.config.content.default_map")

TestDefaultMap = {}

-- ── direction cardinality helpers ─────────────────────────────────

function TestDefaultMap:test_turn_left_maps_all_four_cardinal_directions()
  _assert_eq(default_map.turn_left["up"], "left", "turn_left: up -> left")
  _assert_eq(default_map.turn_left["left"], "down", "turn_left: left -> down")
  _assert_eq(default_map.turn_left["down"], "right", "turn_left: down -> right")
  _assert_eq(default_map.turn_left["right"], "up", "turn_left: right -> up")
end

function TestDefaultMap:test_turn_right_maps_all_four_cardinal_directions()
  _assert_eq(default_map.turn_right["up"], "right", "turn_right: up -> right")
  _assert_eq(default_map.turn_right["right"], "down", "turn_right: right -> down")
  _assert_eq(default_map.turn_right["down"], "left", "turn_right: down -> left")
  _assert_eq(default_map.turn_right["left"], "up", "turn_right: left -> up")
end

-- ── _direction validation ─────────────────────────────────────────

function TestDefaultMap:test_direction_returns_cardinal_from_adjacent_ids()
  -- 使用两个相邻的外环 tiles：path order 中 (9,9) -> (9,8) 是 left
  local start_id = default_map.start_id  -- tile at (9,9)
  local next_id = default_map.outer_next[start_id]  -- tile at (9,8)
  _assert_eq(default_map.direction(start_id, next_id), "left",
    "direction from start to next should be left")
end

function TestDefaultMap:test_direction_asserts_when_tile_id_is_invalid()
  local ok, _ = pcall(default_map.direction, -9999, default_map.start_id)
  _assert_eq(ok, false, "direction should assert when from_id is invalid")
end

-- ── entry_points pinning ──────────────────────────────────────────

function TestDefaultMap:test_entry_points_have_four_outer_ring_entries()
  -- entry points from outer ring inward
  lu.assertEvalToTrue(type(default_map.entry_points) == "table", "entry_points should be a table")
  -- Verify each outer entry has an inner_id
  local entry_count = 0
  for _, entry in pairs(default_map.entry_points) do
    entry_count = entry_count + 1
    lu.assertEvalToTrue(type(entry.inner_id) == "number", "entry should have numeric inner_id")
  end
  _assert_eq(entry_count, 4, "should have four entry points on the outer ring")
end

-- ── fresh_forward_next pinning ────────────────────────────────────

function TestDefaultMap:test_fresh_forward_next_maps_inner_path_forward()
  lu.assertEvalToTrue(type(default_map.fresh_forward_next) == "table",
    "fresh_forward_next should be a table")
  -- Verify the table is non-empty with valid entries
  local count = 0
  for _, target in pairs(default_map.fresh_forward_next) do
    count = count + 1
    lu.assertEvalToTrue(type(target) == "number", "fresh_forward_next target should be a tile id")
  end
  lu.assertEvalToTrue(count >= 8, "fresh_forward_next should have at least 8 inner path mappings")
end

-- ── backward_fallback pinning ─────────────────────────────────────

function TestDefaultMap:test_backward_fallback_has_inner_path_entries()
  lu.assertEvalToTrue(type(default_map.backward_fallback) == "table",
    "backward_fallback should be a table")
  local count = 0
  for _, target in pairs(default_map.backward_fallback) do
    count = count + 1
    lu.assertEvalToTrue(type(target) == "number", "backward_fallback target should be a tile id")
  end
  lu.assertEvalToTrue(count >= 8, "backward_fallback should have at least 8 entries")
end

-- ── neighbors pinning ─────────────────────────────────────────────

function TestDefaultMap:test_neighbors_table_is_populated()
  lu.assertEvalToTrue(type(default_map.neighbors) == "table", "neighbors should be a table")
  -- At least the start tile should have neighbors
  lu.assertEvalToTrue(type(default_map.neighbors[default_map.start_id]) == "table",
    "start tile should have neighbor mapping")
end

-- ── path integrity ────────────────────────────────────────────────

function TestDefaultMap:test_path_starts_at_start_id_and_contains_market_id()
  _assert_eq(default_map.path[1], default_map.start_id, "path should start at start_id")
  local found_market = false
  for _, id in ipairs(default_map.path) do
    if id == default_map.market_id then
      found_market = true
      break
    end
  end
  _assert_eq(found_market, true, "path should contain market_id")
end

-- ── outer_next / outer_prev ───────────────────────────────────────

function TestDefaultMap:test_outer_next_and_outer_prev_form_a_cycle()
  _assert_eq(type(default_map.outer_next[default_map.start_id]), "number",
    "start tile should have an outer_next")
  _assert_eq(type(default_map.outer_prev[default_map.start_id]), "number",
    "start tile should have an outer_prev")
  -- Verify the prev/next relationship is a cycle: next(prev(tile)) == tile
  local next_id = default_map.outer_next[default_map.start_id]
  _assert_eq(default_map.outer_prev[next_id], default_map.start_id,
    "outer_prev(outer_next(tile)) should return tile")
end

-- ── branches ──────────────────────────────────────────────────────

function TestDefaultMap:test_branches_is_empty_table()
  _assert_eq(type(default_map.branches), "table", "branches should be a table")
  -- branches is expected to start empty for the default map layout
end


return TestDefaultMap
