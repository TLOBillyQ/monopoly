local direction = require("src.rules.board.direction")

local _M = direction._M_test

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_simple_map(neighbors, outer_next_map)
  return {
    outer_next = outer_next_map or {},
    entry_points = {},
    neighbors = neighbors or {},
    fresh_forward_next = nil,
    outer_prev = {},
    direction = function(a, b) return "up" end,
  }
end

describe("domain direction coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("sorted_dirs_comparator known priority", function()
    _assert_eq(_M._sorted_dirs_comparator("up", "down"), true, "up < down by priority")
    _assert_eq(_M._sorted_dirs_comparator("down", "up"), false, "down not < up")
  end)

  it("sorted_dirs_comparator equal priority falls back to string", function()
    _assert_eq(_M._sorted_dirs_comparator("custom_a", "custom_b"), true,
      "same (unknown) priority falls back to string compare")
    _assert_eq(_M._sorted_dirs_comparator("custom_b", "custom_a"), false,
      "string compare: b > a")
  end)

  it("sorted_dirs_comparator unknown vs known", function()
    _assert_eq(_M._sorted_dirs_comparator("up", "custom"), true,
      "known priority 1 < unknown 100")
    _assert_eq(_M._sorted_dirs_comparator("custom", "up"), false,
      "unknown 100 not < known 1")
  end)

  it("pick_any_dir returns first non-avoided", function()
    local neigh = { up = 10, right = 20 }
    local dir, id = _M._pick_any_dir(neigh, "up")
    _assert_eq(dir, "right", "should pick right when up is avoided")
    _assert_eq(id, 20, "should return tile id")
  end)

  it("pick_any_dir nil avoid returns first", function()
    local neigh = { up = 5 }
    local dir, id = _M._pick_any_dir(neigh, nil)
    _assert_eq(dir, "up", "nil avoid should allow picking up")
    _assert_eq(id, 5, "should return correct id")
  end)

  it("pick_any_dir all avoided returns nil", function()
    local neigh = { up = 5 }
    local dir, id = _M._pick_any_dir(neigh, "up")
    _assert_eq(dir, nil, "all dirs avoided should return nil")
    _assert_eq(id, nil, "all dirs avoided should return nil id")
  end)

  it("pick_unique_dir two non-avoided returns nil", function()
    local neigh = { up = 1, right = 2 }
    local dir, id = _M._pick_unique_dir(neigh, nil)
    _assert_eq(dir, nil, "multiple dirs should return nil (not unique)")
    _assert_eq(id, nil, "multiple dirs id should be nil")
  end)

  it("pick_unique_dir single non-avoided returns it", function()
    local neigh = { up = 1, right = 2 }
    local dir, id = _M._pick_unique_dir(neigh, "right")
    _assert_eq(dir, "up", "unique remaining dir should be up")
    _assert_eq(id, 1, "unique remaining id should be 1")
  end)

  it("pick_unique_dir all avoided returns nil", function()
    local neigh = { up = 1 }
    local dir, id = _M._pick_unique_dir(neigh, "up")
    _assert_eq(dir, nil, "all avoided returns nil")
    _assert_eq(id, nil, "all avoided id is nil")
  end)

  it("resolve_forward_next_id outer_next path", function()
    local map = _make_simple_map({ [1] = { up = 2 } }, { [1] = 3 })
    local next_id, entered = direction.resolve_forward_next_id(map, 1, { up = 2 }, "up", nil, true, nil)
    _assert_eq(next_id, 3, "outer_next should be preferred")
    _assert_eq(entered, false, "no inner entry")
  end)

  it("resolve_forward_next_id facing path", function()
    local map = _make_simple_map({ [1] = { up = 5 } }, {})
    local next_id, entered = direction.resolve_forward_next_id(map, 1, { up = 5 }, "up", nil, true, nil)
    _assert_eq(next_id, 5, "facing direction should be used")
    _assert_eq(entered, false, "not entered inner")
  end)

  it("resolve_forward_next_id fallback path", function()
    local map = _make_simple_map({}, {})
    local neigh = { right = 7 }
    local next_id, entered = direction.resolve_forward_next_id(map, 1, neigh, "up", nil, true, nil)
    _assert_eq(next_id, 7, "fallback should pick unique dir")
    _assert_eq(entered, false, "not entered inner")
  end)

  it("resolve_forward_next_id outer_next entry point even parity", function()
    local map = {
      outer_next = { [1] = 3 },
      entry_points = { [1] = { inner_id = 99 } },
      neighbors = {},
      fresh_forward_next = nil,
      outer_prev = {},
      direction = function() return "up" end,
    }
    local next_id, entered = direction.resolve_forward_next_id(map, 1, {}, "up", 4, true, nil)
    _assert_eq(next_id, 99, "even parity with entry should enter inner")
    _assert_eq(entered, true, "entered_inner should be true")
  end)

  it("resolve_forward_next_id outer_next entry point odd parity", function()
    local map = {
      outer_next = { [1] = 3 },
      entry_points = { [1] = { inner_id = 99 } },
      neighbors = {},
      fresh_forward_next = nil,
      outer_prev = {},
      direction = function() return "up" end,
    }
    local next_id, entered = direction.resolve_forward_next_id(map, 1, {}, "up", 3, true, nil)
    _assert_eq(next_id, 3, "odd parity should not enter inner")
    _assert_eq(entered, false, "not entered inner on odd parity")
  end)

  it("resolve_forward_next_id fresh_forward when no facing", function()
    local map = {
      outer_next = {},
      entry_points = {},
      neighbors = {},
      fresh_forward_next = { [1] = 42 },
      outer_prev = {},
      direction = function() return "up" end,
    }
    local next_id, entered = direction.resolve_forward_next_id(map, 1, {}, nil, nil, true, nil)
    _assert_eq(next_id, 42, "fresh_forward_next should be used when no facing")
    _assert_eq(entered, false, "not entered inner")
  end)

  it("normalize_forward_step_context table passthrough", function()
    local ctx = { parity = 3, entered_inner = true, skip_entry_on_tile_id = 5 }
    local result = direction.normalize_forward_step_context(ctx)
    _assert_eq(result, ctx, "table context should be returned as-is")
  end)

  it("normalize_forward_step_context parity wraps", function()
    local result = direction.normalize_forward_step_context(7)
    _assert_eq(result.parity, 7, "parity should be set from number")
    _assert_eq(result.entered_inner, false, "entered_inner should default to false")
    _assert_eq(result.skip_entry_on_tile_id, nil, "skip_entry_on_tile_id should be nil")
  end)

  it("resolve_backward_next_source facing reverse", function()
    local map = { outer_prev = {}, backward_fallback = nil }
    local neigh = { down = 8 }
    local result = direction.resolve_backward_next_source(map, 1, neigh, "up")
    _assert_eq(result.next_id, 8, "reverse of facing (down) should be used")
    _assert_eq(result.source, "facing_reverse_neighbor", "source should be facing_reverse_neighbor")
  end)

  it("resolve_backward_next_source outer_prev", function()
    local map = { outer_prev = { [1] = 10 }, backward_fallback = nil }
    local neigh = {}
    local result = direction.resolve_backward_next_source(map, 1, neigh, nil)
    _assert_eq(result.next_id, 10, "outer_prev should be used")
    _assert_eq(result.source, "outer_prev", "source should be outer_prev")
  end)

  it("resolve_backward_next_source backward_fallback", function()
    local map = { outer_prev = {}, backward_fallback = { [1] = 20 } }
    local neigh = {}
    local result = direction.resolve_backward_next_source(map, 1, neigh, nil)
    _assert_eq(result.next_id, 20, "backward_fallback should be used")
    _assert_eq(result.source, "backward_fallback", "source should be backward_fallback")
  end)

  it("resolve_backward_next_source neighbor_fallback", function()
    local map = { outer_prev = {}, backward_fallback = nil }
    local neigh = { right = 30 }
    local result = direction.resolve_backward_next_source(map, 1, neigh, nil)
    _assert_eq(result.next_id, 30, "neighbor_fallback should be used when no map entry")
    _assert_eq(result.source, "neighbor_fallback", "source should be neighbor_fallback")
  end)

  it("resolve_backward_next_source no next_id", function()
    local map = { outer_prev = {}, backward_fallback = nil }
    local neigh = {}
    local result = direction.resolve_backward_next_source(map, 1, neigh, nil)
    _assert_eq(result.next_id, nil, "no options should return nil next_id")
    _assert_eq(result.source, nil, "no options should return nil source")
  end)

  it("resolve_backward_next_source no facing skips facing_reverse", function()
    local map = { outer_prev = {}, backward_fallback = nil }
    local neigh = { left = 9 }
    local result = direction.resolve_backward_next_source(map, 1, neigh, nil)
    _assert_eq(result.next_id, 9, "no facing should fall to neighbor_fallback")
    _assert_eq(result.source, "neighbor_fallback", "source should be neighbor_fallback")
  end)

  it("resolve_fallback_next unique dir", function()
    local neigh = { up = 5, down = 10 }
    local next_id = _M._resolve_fallback_next(neigh, "up")
    _assert_eq(next_id, 5, "unique non-back dir should be picked")
  end)

  it("resolve_fallback_next multiple dirs picks any", function()
    local neigh = { up = 5, right = 7, left = 9 }
    local next_id = _M._resolve_fallback_next(neigh, "down")
    assert(next_id ~= nil, "should pick some non-nil direction")
  end)

  it("resolve_fallback_next only back dir picks any", function()
    local neigh = { down = 3 }
    local next_id = _M._resolve_fallback_next(neigh, "up")
    _assert_eq(next_id, 3, "only back dir available → pick it as any")
  end)
end)
