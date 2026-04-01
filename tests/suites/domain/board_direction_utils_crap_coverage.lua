local board = require("src.rules.board.init")

local _pick_any_dir = board._M_test._pick_any_dir

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _test_pick_any_dir_all_four_dirs_no_avoid()
  local neigh = { up = 1, right = 2, down = 3, left = 4 }
  local dir, id = _pick_any_dir(neigh, nil)
  _assert_eq(dir, "up", "all dirs: picks up (highest priority)")
  _assert_eq(id, 1, "all dirs: returns correct neighbor id")
end

local function _test_pick_any_dir_avoid_up_picks_right()
  local neigh = { up = 1, right = 2, down = 3, left = 4 }
  local dir, id = _pick_any_dir(neigh, "up")
  _assert_eq(dir, "right", "avoid up: should pick right")
  _assert_eq(id, 2, "avoid up: correct id for right")
end

local function _test_pick_any_dir_avoid_right_picks_up()
  local neigh = { up = 10, right = 20 }
  local dir, id = _pick_any_dir(neigh, "right")
  _assert_eq(dir, "up", "avoid right: should pick up")
  _assert_eq(id, 10, "avoid right: correct id")
end

local function _test_pick_any_dir_only_left_no_avoid()
  local neigh = { left = 99 }
  local dir, id = _pick_any_dir(neigh, nil)
  _assert_eq(dir, "left", "only left: picks left")
  _assert_eq(id, 99, "only left: correct id")
end

local function _test_pick_any_dir_only_left_avoid_left_returns_nil()
  local neigh = { left = 99 }
  local dir, id = _pick_any_dir(neigh, "left")
  _assert_eq(dir, nil, "avoid only dir: returns nil dir")
  _assert_eq(id, nil, "avoid only dir: returns nil id")
end

local function _test_pick_any_dir_down_vs_left_picks_down()
  local neigh = { down = 30, left = 40 }
  local dir, id = _pick_any_dir(neigh, nil)
  _assert_eq(dir, "down", "down vs left: picks down (priority 3 < 4)")
  _assert_eq(id, 30, "down vs left: correct id")
end

local function _test_pick_any_dir_empty_neigh_returns_nil()
  local neigh = {}
  local dir, id = _pick_any_dir(neigh, nil)
  _assert_eq(dir, nil, "empty neigh: returns nil dir")
  _assert_eq(id, nil, "empty neigh: returns nil id")
end

return {
  name = "board_direction_utils_crap_coverage",
  tests = {
    { name = "_test_pick_any_dir_all_four_dirs_no_avoid", run = _test_pick_any_dir_all_four_dirs_no_avoid },
    { name = "_test_pick_any_dir_avoid_up_picks_right", run = _test_pick_any_dir_avoid_up_picks_right },
    { name = "_test_pick_any_dir_avoid_right_picks_up", run = _test_pick_any_dir_avoid_right_picks_up },
    { name = "_test_pick_any_dir_only_left_no_avoid", run = _test_pick_any_dir_only_left_no_avoid },
    { name = "_test_pick_any_dir_only_left_avoid_left_returns_nil", run = _test_pick_any_dir_only_left_avoid_left_returns_nil },
    { name = "_test_pick_any_dir_down_vs_left_picks_down", run = _test_pick_any_dir_down_vs_left_picks_down },
    { name = "_test_pick_any_dir_empty_neigh_returns_nil", run = _test_pick_any_dir_empty_neigh_returns_nil },
  },
}
