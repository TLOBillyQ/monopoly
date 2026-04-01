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
  },
}
