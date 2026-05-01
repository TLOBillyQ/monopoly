local board = require("src.rules.board.init")

local _pick_unique_dir = board._M_test._pick_unique_dir
local _resolve_fallback_next = board._M_test._resolve_fallback_next
local _resolve_backward_from_neighbors = board._M_test._resolve_backward_from_neighbors

local opposite = { up = "down", down = "up", left = "right", right = "left" }

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

describe("board_direction_crap_coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("_test_pick_unique_dir_returns_single_non_avoided_dir", function()
    local neigh = { up = 1, down = 2 }
    local dir, id = _pick_unique_dir(neigh, "up")
    _assert_eq(dir, "down", "pick_unique avoid up: should pick down")
    _assert_eq(id, 2, "pick_unique avoid up: should return down id")
  end)

  it("_test_pick_unique_dir_returns_nil_when_two_non_avoided_dirs_exist", function()
    local neigh = { up = 1, right = 2, down = 3 }
    local dir, id = _pick_unique_dir(neigh, "up")
    _assert_eq(dir, nil, "pick_unique avoid up with right+down: should return nil dir")
    _assert_eq(id, nil, "pick_unique avoid up with right+down: should return nil id")
  end)

  it("_test_pick_unique_dir_no_avoid_single_dir_returns_dir", function()
    local neigh = { left = 5 }
    local dir, id = _pick_unique_dir(neigh, nil)
    _assert_eq(dir, "left", "pick_unique no avoid single: should pick left")
    _assert_eq(id, 5, "pick_unique no avoid single: should return left id")
  end)

  it("_test_pick_unique_dir_no_avoid_multiple_dirs_returns_nil", function()
    local neigh = { up = 1, right = 2 }
    local dir, id = _pick_unique_dir(neigh, nil)
    _assert_eq(dir, nil, "pick_unique no avoid multiple: should return nil dir")
    _assert_eq(id, nil, "pick_unique no avoid multiple: should return nil id")
  end)

  it("_test_pick_unique_dir_empty_neighbors_returns_nil", function()
    local neigh = {}
    local dir, id = _pick_unique_dir(neigh, nil)
    _assert_eq(dir, nil, "pick_unique empty: should return nil dir")
    _assert_eq(id, nil, "pick_unique empty: should return nil id")
  end)

  it("_test_resolve_fallback_next_unique_forward", function()
    local neigh = { up = 1, down = 2 }
    local facing = "up"
    local next_id = _resolve_fallback_next(neigh, facing)
    _assert_eq(opposite[facing], "down", "resolve_fallback opposite check")
    _assert_eq(next_id, 1, "resolve_fallback unique non-back should return forward id")
  end)

  it("_test_resolve_fallback_next_multiple_forward_falls_to_pick_any", function()
    local neigh = { up = 1, right = 2, down = 3 }
    local next_id = _resolve_fallback_next(neigh, "up")
    _assert_eq(next_id, 1, "resolve_fallback multiple non-back should pick up by priority")
  end)

  it("_test_resolve_fallback_next_last_resort_any_dir", function()
    local neigh = { down = 3 }
    local next_id = _resolve_fallback_next(neigh, "up")
    _assert_eq(next_id, 3, "resolve_fallback only back dir should return it as last resort")
  end)

  it("_test_resolve_fallback_next_no_neighbors_returns_nil", function()
    local neigh = {}
    local next_id = _resolve_fallback_next(neigh, "up")
    _assert_eq(next_id, nil, "resolve_fallback empty neighbors should return nil")
  end)

  it("_test_resolve_backward_from_neighbors_unique_backward", function()
    local neigh = { up = 1, down = 2 }
    local next_id = _resolve_backward_from_neighbors(neigh, "up")
    _assert_eq(next_id, 2, "resolve_backward unique non-facing should return down id")
  end)

  it("_test_resolve_backward_from_neighbors_multiple_non_facing_falls_to_pick_any", function()
    local neigh = { up = 1, right = 2, down = 3 }
    local next_id = _resolve_backward_from_neighbors(neigh, "up")
    _assert_eq(next_id, 2, "resolve_backward multiple non-facing should pick right by priority")
  end)

  it("_test_resolve_backward_from_neighbors_only_facing_last_resort", function()
    local neigh = { up = 3 }
    local next_id = _resolve_backward_from_neighbors(neigh, "up")
    _assert_eq(next_id, 3, "resolve_backward only facing should return it as last resort")
  end)

  it("_test_resolve_backward_from_neighbors_no_neighbors_returns_nil", function()
    local neigh = {}
    local next_id = _resolve_backward_from_neighbors(neigh, "up")
    _assert_eq(next_id, nil, "resolve_backward empty neighbors should return nil")
  end)
end)
