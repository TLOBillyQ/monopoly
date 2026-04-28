local board = require("src.rules.board.init")

local _sorted_dirs_comparator = board._M_test._sorted_dirs_comparator
local _pick_any_dir = board._M_test._pick_any_dir

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _test_comparator_up_before_right()
  _assert_eq(_sorted_dirs_comparator("up", "right"), true, "up < right")
end

local function _test_comparator_right_before_down()
  _assert_eq(_sorted_dirs_comparator("right", "down"), true, "right < down")
end

local function _test_comparator_down_before_left()
  _assert_eq(_sorted_dirs_comparator("down", "left"), true, "down < left")
end

local function _test_comparator_left_not_before_up()
  _assert_eq(_sorted_dirs_comparator("left", "up"), false, "left not < up")
end

local function _test_comparator_same_priority_uses_tostring()
  _assert_eq(_sorted_dirs_comparator("a", "b"), true, "a < b lexicographic")
  _assert_eq(_sorted_dirs_comparator("b", "a"), false, "b not < a lexicographic")
end

local function _test_comparator_same_key_returns_false()
  _assert_eq(_sorted_dirs_comparator("up", "up"), false, "same key not strictly less")
end

local function _test_comparator_unknown_before_known_when_alpha_lower()
  _assert_eq(_sorted_dirs_comparator("up", "alpha"), true, "up (priority 1) < alpha (priority 100)")
  _assert_eq(_sorted_dirs_comparator("alpha", "up"), false, "alpha not < up")
end

local function _test_pick_any_dir_returns_first_dir()
  local neigh = { up = 10, right = 20 }
  local dir, id = _pick_any_dir(neigh, nil)
  _assert_eq(dir, "up", "should pick 'up' first (priority 1)")
  _assert_eq(id, 10, "should return neighbor id for 'up'")
end

local function _test_pick_any_dir_avoids_specified_dir()
  local neigh = { up = 10, right = 20 }
  local dir, id = _pick_any_dir(neigh, "up")
  _assert_eq(dir, "right", "should pick 'right' when 'up' is avoided")
  _assert_eq(id, 20, "should return neighbor id for 'right'")
end

local function _test_pick_any_dir_returns_nil_if_only_avoid()
  local neigh = { up = 10 }
  local dir, id = _pick_any_dir(neigh, "up")
  _assert_eq(dir, nil, "should return nil dir when only option is avoided")
  _assert_eq(id, nil, "should return nil id when only option is avoided")
end

local function _test_pick_any_dir_single_dir_no_avoid()
  local neigh = { down = 5 }
  local dir, id = _pick_any_dir(neigh, nil)
  _assert_eq(dir, "down", "single dir returns that dir")
  _assert_eq(id, 5, "single dir returns correct id")
end

local function _test_pick_any_dir_prefers_priority_order()
  local neigh = { left = 40, right = 20, down = 30, up = 10 }
  local dir, _ = _pick_any_dir(neigh, nil)
  _assert_eq(dir, "up", "should pick 'up' (priority 1) over all others")
end

local function _test_pick_any_dir_nil_neigh_asserts()
  local ok, _ = pcall(_pick_any_dir, nil, nil)
  _assert_eq(ok, false, "should assert when neigh is nil")
end

-- Board instance tests (mine and roadblock methods)

local function _make_board()
  local tiles = { { id = "T1", type = "land" }, { id = "T2", type = "start" } }
  local tile_lookup = {}
  for _, t in ipairs(tiles) do tile_lookup[t.id] = t end
  return board:new({
    path = tiles,
    tile_lookup = tile_lookup,
    branches = {},
    map = {},
    overlays = { roadblocks = {}, mines = {} },
  })
end

local function _test_board_length()
  local b = _make_board()
  _assert_eq(b:length(), 2, "length should return path size")
end

local function _test_board_get_tile()
  local b = _make_board()
  local t = b:get_tile(1)
  _assert_eq(t.id, "T1", "get_tile(1) should return T1")
end

local function _test_board_index_of_tile_id()
  local b = _make_board()
  _assert_eq(b:index_of_tile_id("T2"), 2, "index_of_tile_id should return 2 for T2")
end

local function _test_board_get_tile_by_id()
  local b = _make_board()
  local t = b:get_tile_by_id("T1")
  _assert_eq(t.id, "T1", "get_tile_by_id should return T1")
end

local function _test_board_find_first_by_type()
  local b = _make_board()
  local idx, tile = b:find_first_by_type("start")
  _assert_eq(idx, 2, "find_first_by_type should return index 2 for start")
  _assert_eq(tile.id, "T2", "tile should be T2")
end

local function _test_board_find_first_by_type_not_found()
  local b = _make_board()
  local idx = b:find_first_by_type("hospital")
  _assert_eq(idx, nil, "find_first_by_type should return nil when not found")
end

local function _test_board_place_mine_nil_data()
  local b = _make_board()
  b:place_mine(1, nil)
  _assert_eq(b:has_mine(1), true, "has_mine should return true after placing mine with nil data")
  _assert_eq(b.overlays.mines[1], true, "mine stored as true when data is nil")
end

local function _test_board_place_mine_with_data()
  local b = _make_board()
  b:place_mine(1, { owner_id = 1001 })
  _assert_eq(b:has_mine(1), true, "has_mine should return true after placing mine with data")
  _assert_eq(b.overlays.mines[1].owner_id, 1001, "mine data should be stored")
end

local function _test_board_get_mine()
  local b = _make_board()
  b:place_mine(1, { armed = false })
  local mine = b:get_mine(1)
  _assert_eq(mine.armed, false, "get_mine should return mine data")
end

local function _test_board_arm_mine_returns_true()
  local b = _make_board()
  b:place_mine(1, { armed = false })
  _assert_eq(b:arm_mine(1), true, "arm_mine should return true on success")
  _assert_eq(b.overlays.mines[1].armed, true, "mine should be armed")
end

local function _test_board_arm_mine_already_armed_returns_false()
  local b = _make_board()
  b:place_mine(1, { armed = true })
  _assert_eq(b:arm_mine(1), false, "arm_mine should return false when already armed")
end

local function _test_board_arm_mine_not_table_returns_false()
  local b = _make_board()
  b:place_mine(1, nil)
  _assert_eq(b:arm_mine(1), false, "arm_mine should return false when mine is not a table")
end

local function _test_board_clear_mine()
  local b = _make_board()
  b:place_mine(1, nil)
  b:clear_mine(1)
  _assert_eq(b:has_mine(1), false, "has_mine should return false after clear")
end

local function _test_board_roadblock_operations()
  local b = _make_board()
  _assert_eq(b:has_roadblock(1), false, "no roadblock initially")
  b:place_roadblock(1)
  _assert_eq(b:has_roadblock(1), true, "has_roadblock after place")
  b:clear_roadblock(1)
  _assert_eq(b:has_roadblock(1), false, "no roadblock after clear")
end

local function _test_board_get_overlays()
  local b = _make_board()
  local overlays = b:get_overlays()
  assert(type(overlays) == "table", "get_overlays should return table")
end

local function _test_board_clear_all()
  local b = _make_board()
  b:place_roadblock(1)
  b:place_mine(1, nil)
  b:clear_all(1)
  _assert_eq(b:has_roadblock(1), false, "roadblock cleared")
  _assert_eq(b:has_mine(1), false, "mine cleared")
end

local function _test_board_advance_basic()
  local b = _make_board()
  local new_idx, passed = b:advance(1, 1, nil)
  _assert_eq(new_idx, 2, "advance 1 step from 1 should reach 2")
  _assert_eq(passed, 0, "should not pass start")
end

local function _test_board_advance_wraps()
  local b = _make_board()
  local new_idx, passed = b:advance(2, 1, nil)
  _assert_eq(new_idx, 1, "advance past end should wrap to 1")
  _assert_eq(passed, 1, "should have passed start once")
end

return {
  name = "board_init_crap_coverage",
  tests = {
    { name = "_test_comparator_up_before_right", run = _test_comparator_up_before_right },
    { name = "_test_comparator_right_before_down", run = _test_comparator_right_before_down },
    { name = "_test_comparator_down_before_left", run = _test_comparator_down_before_left },
    { name = "_test_comparator_left_not_before_up", run = _test_comparator_left_not_before_up },
    { name = "_test_comparator_same_priority_uses_tostring", run = _test_comparator_same_priority_uses_tostring },
    { name = "_test_comparator_same_key_returns_false", run = _test_comparator_same_key_returns_false },
    { name = "_test_comparator_unknown_before_known_when_alpha_lower", run = _test_comparator_unknown_before_known_when_alpha_lower },
    { name = "_test_pick_any_dir_returns_first_dir", run = _test_pick_any_dir_returns_first_dir },
    { name = "_test_pick_any_dir_avoids_specified_dir", run = _test_pick_any_dir_avoids_specified_dir },
    { name = "_test_pick_any_dir_returns_nil_if_only_avoid", run = _test_pick_any_dir_returns_nil_if_only_avoid },
    { name = "_test_pick_any_dir_single_dir_no_avoid", run = _test_pick_any_dir_single_dir_no_avoid },
    { name = "_test_pick_any_dir_prefers_priority_order", run = _test_pick_any_dir_prefers_priority_order },
    { name = "_test_pick_any_dir_nil_neigh_asserts", run = _test_pick_any_dir_nil_neigh_asserts },
    { name = "board length", run = _test_board_length },
    { name = "board get_tile", run = _test_board_get_tile },
    { name = "board index_of_tile_id", run = _test_board_index_of_tile_id },
    { name = "board get_tile_by_id", run = _test_board_get_tile_by_id },
    { name = "board find_first_by_type", run = _test_board_find_first_by_type },
    { name = "board find_first_by_type not found", run = _test_board_find_first_by_type_not_found },
    { name = "board place_mine nil data", run = _test_board_place_mine_nil_data },
    { name = "board place_mine with data", run = _test_board_place_mine_with_data },
    { name = "board get_mine", run = _test_board_get_mine },
    { name = "board arm_mine returns true", run = _test_board_arm_mine_returns_true },
    { name = "board arm_mine already armed returns false", run = _test_board_arm_mine_already_armed_returns_false },
    { name = "board arm_mine not table returns false", run = _test_board_arm_mine_not_table_returns_false },
    { name = "board clear_mine", run = _test_board_clear_mine },
    { name = "board roadblock operations", run = _test_board_roadblock_operations },
    { name = "board get_overlays", run = _test_board_get_overlays },
    { name = "board clear_all", run = _test_board_clear_all },
    { name = "board advance basic", run = _test_board_advance_basic },
    { name = "board advance wraps", run = _test_board_advance_wraps },
  },
}
