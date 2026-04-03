local board = require("src.rules.board.init")

local _pick_unique_dir = board._M_test._pick_unique_dir
local _resolve_fallback_next = board._M_test._resolve_fallback_next
local _resolve_backward_from_neighbors = board._M_test._resolve_backward_from_neighbors

local opposite = { up = "down", down = "up", left = "right", right = "left" }

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _test_pick_unique_dir_returns_single_non_avoided_dir()
  local neigh = { up = 1, down = 2 }
  local dir, id = _pick_unique_dir(neigh, "up")
  _assert_eq(dir, "down", "pick_unique avoid up: should pick down")
  _assert_eq(id, 2, "pick_unique avoid up: should return down id")
end

local function _test_pick_unique_dir_returns_nil_when_two_non_avoided_dirs_exist()
  local neigh = { up = 1, right = 2, down = 3 }
  local dir, id = _pick_unique_dir(neigh, "up")
  _assert_eq(dir, nil, "pick_unique avoid up with right+down: should return nil dir")
  _assert_eq(id, nil, "pick_unique avoid up with right+down: should return nil id")
end

local function _test_pick_unique_dir_no_avoid_single_dir_returns_dir()
  local neigh = { left = 5 }
  local dir, id = _pick_unique_dir(neigh, nil)
  _assert_eq(dir, "left", "pick_unique no avoid single: should pick left")
  _assert_eq(id, 5, "pick_unique no avoid single: should return left id")
end

local function _test_pick_unique_dir_no_avoid_multiple_dirs_returns_nil()
  local neigh = { up = 1, right = 2 }
  local dir, id = _pick_unique_dir(neigh, nil)
  _assert_eq(dir, nil, "pick_unique no avoid multiple: should return nil dir")
  _assert_eq(id, nil, "pick_unique no avoid multiple: should return nil id")
end

local function _test_pick_unique_dir_empty_neighbors_returns_nil()
  local neigh = {}
  local dir, id = _pick_unique_dir(neigh, nil)
  _assert_eq(dir, nil, "pick_unique empty: should return nil dir")
  _assert_eq(id, nil, "pick_unique empty: should return nil id")
end

local function _test_resolve_fallback_next_unique_forward()
  local neigh = { up = 1, down = 2 }
  local facing = "up"
  local next_id = _resolve_fallback_next(neigh, facing)
  _assert_eq(opposite[facing], "down", "resolve_fallback opposite check")
  _assert_eq(next_id, 1, "resolve_fallback unique non-back should return forward id")
end

local function _test_resolve_fallback_next_multiple_forward_falls_to_pick_any()
  local neigh = { up = 1, right = 2, down = 3 }
  local next_id = _resolve_fallback_next(neigh, "up")
  _assert_eq(next_id, 1, "resolve_fallback multiple non-back should pick up by priority")
end

local function _test_resolve_fallback_next_last_resort_any_dir()
  local neigh = { down = 3 }
  local next_id = _resolve_fallback_next(neigh, "up")
  _assert_eq(next_id, 3, "resolve_fallback only back dir should return it as last resort")
end

local function _test_resolve_fallback_next_no_neighbors_returns_nil()
  local neigh = {}
  local next_id = _resolve_fallback_next(neigh, "up")
  _assert_eq(next_id, nil, "resolve_fallback empty neighbors should return nil")
end

local function _test_resolve_backward_from_neighbors_unique_backward()
  local neigh = { up = 1, down = 2 }
  local next_id = _resolve_backward_from_neighbors(neigh, "up")
  _assert_eq(next_id, 2, "resolve_backward unique non-facing should return down id")
end

local function _test_resolve_backward_from_neighbors_multiple_non_facing_falls_to_pick_any()
  local neigh = { up = 1, right = 2, down = 3 }
  local next_id = _resolve_backward_from_neighbors(neigh, "up")
  _assert_eq(next_id, 2, "resolve_backward multiple non-facing should pick right by priority")
end

local function _test_resolve_backward_from_neighbors_only_facing_last_resort()
  local neigh = { up = 3 }
  local next_id = _resolve_backward_from_neighbors(neigh, "up")
  _assert_eq(next_id, 3, "resolve_backward only facing should return it as last resort")
end

local function _test_resolve_backward_from_neighbors_no_neighbors_returns_nil()
  local neigh = {}
  local next_id = _resolve_backward_from_neighbors(neigh, "up")
  _assert_eq(next_id, nil, "resolve_backward empty neighbors should return nil")
end

return {
  name = "board_direction_crap_coverage",
  tests = {
    { name = "_test_pick_unique_dir_returns_single_non_avoided_dir", run = _test_pick_unique_dir_returns_single_non_avoided_dir },
    {
      name = "_test_pick_unique_dir_returns_nil_when_two_non_avoided_dirs_exist",
      run = _test_pick_unique_dir_returns_nil_when_two_non_avoided_dirs_exist,
    },
    { name = "_test_pick_unique_dir_no_avoid_single_dir_returns_dir", run = _test_pick_unique_dir_no_avoid_single_dir_returns_dir },
    { name = "_test_pick_unique_dir_no_avoid_multiple_dirs_returns_nil", run = _test_pick_unique_dir_no_avoid_multiple_dirs_returns_nil },
    { name = "_test_pick_unique_dir_empty_neighbors_returns_nil", run = _test_pick_unique_dir_empty_neighbors_returns_nil },
    { name = "_test_resolve_fallback_next_unique_forward", run = _test_resolve_fallback_next_unique_forward },
    {
      name = "_test_resolve_fallback_next_multiple_forward_falls_to_pick_any",
      run = _test_resolve_fallback_next_multiple_forward_falls_to_pick_any,
    },
    { name = "_test_resolve_fallback_next_last_resort_any_dir", run = _test_resolve_fallback_next_last_resort_any_dir },
    { name = "_test_resolve_fallback_next_no_neighbors_returns_nil", run = _test_resolve_fallback_next_no_neighbors_returns_nil },
    { name = "_test_resolve_backward_from_neighbors_unique_backward", run = _test_resolve_backward_from_neighbors_unique_backward },
    {
      name = "_test_resolve_backward_from_neighbors_multiple_non_facing_falls_to_pick_any",
      run = _test_resolve_backward_from_neighbors_multiple_non_facing_falls_to_pick_any,
    },
    {
      name = "_test_resolve_backward_from_neighbors_only_facing_last_resort",
      run = _test_resolve_backward_from_neighbors_only_facing_last_resort,
    },
    {
      name = "_test_resolve_backward_from_neighbors_no_neighbors_returns_nil",
      run = _test_resolve_backward_from_neighbors_no_neighbors_returns_nil,
    },
  },
}
