local target_direction = require("src.rules.board.target_direction")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

-- Minimal board seam: build_queues only ever calls board:get_tile(idx).
local function _board(tiles)
  return {
    get_tile = function(_, idx)
      return tiles[idx]
    end,
  }
end

-- Drive build_queues with empty direction sets so classification always falls
-- through to the geometry heuristic in _direction_from_geometry, letting each
-- test pin one branch of that heuristic.
local function _classify(tiles, by_dist, start_tile, max_dist)
  local board = _board(tiles)
  return target_direction.build_queues(by_dist, max_dist, board, { set = {} }, { set = {} }, start_tile)
end

describe("target_direction.build_queues geometry classification", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("_test_row_dominant_positive_delta_is_backward", function()
    -- dr = +1 dominates dc = 0, so _sign_direction(dr) must resolve backward.
    local bq, fq = _classify({ [2] = { row = 1, col = 0 } }, { [1] = { 2 } }, { row = 0, col = 0 }, 1)
    _assert_eq(#bq, 1, "row-dominant +delta: one backward entry")
    _assert_eq(bq[1], 2, "row-dominant +delta: idx 2 lands in backward queue")
    _assert_eq(#fq, 0, "row-dominant +delta: forward queue stays empty")
  end)

  it("_test_column_positive_delta_is_backward", function()
    -- dr = 0 so the row branch is skipped; the column branch (abs(dc) > 0)
    -- with dc = +1 must resolve backward.
    local bq, fq = _classify({ [2] = { row = 0, col = 1 } }, { [1] = { 2 } }, { row = 0, col = 0 }, 1)
    _assert_eq(#bq, 1, "column +delta: one backward entry")
    _assert_eq(bq[1], 2, "column +delta: idx 2 lands in backward queue")
    _assert_eq(#fq, 0, "column +delta: forward queue stays empty")
  end)

  it("_test_colocated_tile_falls_through_to_forward", function()
    -- dr = dc = 0: neither the row branch nor the column branch fires, so the
    -- final "forward" fallback must win (not the column sign of a zero delta).
    local bq, fq = _classify({ [2] = { row = 5, col = 5 } }, { [1] = { 2 } }, { row = 5, col = 5 }, 1)
    _assert_eq(#fq, 1, "co-located tile: one forward entry")
    _assert_eq(fq[1], 2, "co-located tile: idx 2 lands in forward queue")
    _assert_eq(#bq, 0, "co-located tile: backward queue stays empty")
  end)

  it("_test_equal_deltas_prefer_column_sign", function()
    -- abs(dr) == abs(dc) == 1: the row branch uses a strict '>' so the tie must
    -- go to the column branch, and dc = -1 resolves forward.
    local bq, fq = _classify({ [2] = { row = 1, col = -1 } }, { [1] = { 2 } }, { row = 0, col = 0 }, 1)
    _assert_eq(#fq, 1, "equal deltas: one forward entry")
    _assert_eq(fq[1], 2, "equal deltas: idx 2 lands in forward queue via column sign")
    _assert_eq(#bq, 0, "equal deltas: backward queue stays empty")
  end)

  it("_test_missing_tile_is_forward_without_geometry", function()
    -- board:get_tile returns nil: the nil guard must short-circuit to forward
    -- instead of computing geometry on a nil tile.
    local bq, fq = _classify({}, { [1] = { 2 } }, { row = 0, col = 0 }, 1)
    _assert_eq(#fq, 1, "missing tile: one forward entry")
    _assert_eq(fq[1], 2, "missing tile: idx 2 lands in forward queue")
    _assert_eq(#bq, 0, "missing tile: backward queue stays empty")
  end)

  it("_test_distance_zero_bucket_is_not_walked", function()
    -- The distance loop starts at 1, so a bucket keyed at 0 must be ignored even
    -- though its tile would otherwise classify as backward.
    local bq, fq = _classify({ [2] = { row = 1, col = 0 } }, { [0] = { 2 } }, { row = 0, col = 0 }, 1)
    _assert_eq(#bq, 0, "distance-0 bucket: nothing enters backward queue")
    _assert_eq(#fq, 0, "distance-0 bucket: nothing enters forward queue")
  end)
end)
