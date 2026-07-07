-- Mutation-pinning specs for src/rules/board/init.lua.
-- Kills survivors the existing board_init/board_direction specs leave alive:
--   * L79  place_mine lazy-init `or {}` (mutated to `and {}`)
--   * L129 advance empty-board guard `length == 0` (mutated to `== 1`)
--   * L130 advance empty-board `return index, 0` (mutated to `index, 1`)
--   * L184 step_forward_by_facing next_step_context.entered_inner `or` (-> `and`)
--   * L209 step_backward_by_facing passed_start `= 1` (mutated to `= 0`)
--   * L211 step_backward_by_facing next_facing map.direction(...) (-> nil)
local board = require("src.rules.board.init")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_board(data)
  return board:new({
    path = data.path or {},
    tile_lookup = data.tile_lookup or {},
    branches = data.branches or {},
    map = data.map or {},
    overlays = data.overlays or { roadblocks = {}, mines = {} },
  })
end

describe("board init mutation pins", function()

  -- L79: `self.overlays.mines = self.overlays.mines or {}`.
  -- With overlays.mines absent, the original `or {}` lazily creates the table so
  -- the subsequent `mines[index] = ...` store succeeds. The `and {}` mutant yields
  -- nil, so indexing nil crashes and the store is lost.
  it("place_mine lazily creates the mines table when absent (L79 'or')", function()
    local b = _make_board({ overlays = { roadblocks = {} } }) -- no mines table
    b:place_mine(3, nil)
    assert(b.overlays.mines ~= nil, "place_mine must create the mines table when absent")
    _assert_eq(b:has_mine(3), true, "mine must be stored after lazy-init")
  end)

  -- L129 + L130: empty-board short-circuit `if length == 0 then return index, 0 end`.
  -- On a zero-length board, original returns the unchanged index with passed_start 0.
  --   * `length == 1` mutant: 0 ~= 1 -> falls into the advance loop -> index/passed shift.
  --   * `return index, 1` mutant: second value becomes 1.
  it("advance short-circuits an empty board to (index, 0) (L129/L130)", function()
    local b = _make_board({ path = {}, branches = {} })
    local idx, passed = b:advance(5, 1, nil)
    _assert_eq(idx, 5, "empty board must return the index unchanged")
    _assert_eq(passed, 0, "empty board must report zero passed_start")
  end)

  -- L211 + L209: step_backward_by_facing lands on the start tile.
  --   * next_facing = map.direction(next_id, current_id) -> nil mutant.
  --   * passed_start = 1 -> 0 mutant when the landing tile is the start.
  it("step_backward_by_facing computes facing and passed_start on start landing (L209/L211)", function()
    local path = { { id = "CURR" }, { id = "PREV" } }
    local tile_lookup = { CURR = path[1], PREV = path[2] }
    local map = {
      start_id = "PREV",
      neighbors = { CURR = { down = "PREV" } },
      outer_prev = {},
      direction = function(a, b) return tostring(a) .. "<-" .. tostring(b) end,
    }
    local b = _make_board({ path = path, tile_lookup = tile_lookup, map = map })

    local next_index, passed_start, next_facing = b:step_backward_by_facing(1, "up")
    _assert_eq(next_index, 2, "backward step from CURR reaches PREV at index 2")
    _assert_eq(passed_start, 1, "landing on the start tile must report passed_start 1 (L209)")
    _assert_eq(next_facing, "PREV<-CURR", "next_facing must be map.direction(next_id, current_id) (L211)")
  end)

  -- L184: next_step_context.entered_inner = step_context.entered_inner or entered_inner.
  -- The fresh step_context has entered_inner = false, so the value collapses to the
  -- local entered_inner (true here because the outer->inner entry fired). The `and`
  -- mutant yields false, which flips can_enter_inner on the follow-up
  -- resolve_forward_facing call and therefore changes the returned next_facing.
  it("step_forward_by_facing propagates entered_inner into next_facing (L184 'or')", function()
    local path = { { id = "CURR" }, { id = "INNER" } }
    local tile_lookup = { CURR = path[1], INNER = path[2] }
    local map = {
      start_id = "START",
      neighbors = {
        CURR = { up = "OUTERNEXT" },
        INNER = { up = "INNER_OUTER" },
      },
      outer_next = {
        CURR = "OUTERNEXT",
        INNER = "INNER_OUTER",
      },
      entry_points = {
        CURR = { inner_id = "INNER" },
        INNER = { inner_id = "INNER2" },
      },
      direction = function(a, b) return tostring(a) .. "|" .. tostring(b) end,
    }
    local b = _make_board({ path = path, tile_lookup = tile_lookup, map = map })

    -- parity 2 (even) enables the outer->inner entry at CURR, so entered_inner=true.
    local next_index, passed_start, next_facing, entered_inner =
      b:step_forward_by_facing(1, nil, 2)

    _assert_eq(next_index, 2, "forward step from CURR enters INNER at index 2")
    _assert_eq(passed_start, 0, "INNER is not the start tile")
    _assert_eq(entered_inner, true, "the outer->inner entry must report entered_inner=true")
    -- With entered_inner carried forward (true), can_enter_inner is false at INNER,
    -- so resolve_forward_facing picks the outer next ("INNER_OUTER"). The `and` mutant
    -- (false) would re-enter and pick "INNER2", yielding "INNER|INNER2".
    _assert_eq(next_facing, "INNER|INNER_OUTER",
      "carried entered_inner must suppress a second inner entry when computing next_facing (L184)")
  end)
end)
