-- Mutation-hardening coverage for src.ui.render.status3d.status_resolve.
-- These cases pin boundary behavior that the happy-path unit/hotspot specs
-- leave indistinguishable from mutated variants (literal/relational/boolean
-- operator mutations). Kept separate from the focused convention spec
-- (status3d_resolve_spec) per the mutation/hardening test boundary.
local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq
local status_resolve = require("src.ui.render.status3d.status_resolve")

local function _hospital_board()
  return {
    get_tile = function()
      return { type = "hospital" }
    end,
  }
end

describe("status3d_resolve_crap_coverage", function()
  -- L23 `(stay_turns or 0) > 0`: a single remaining stay turn must still mark
  -- the location effect active (kills `> 0` → `> 1`).
  it("location stays active with exactly one stay turn", function()
    local game = { board = _hospital_board() }
    local player = { id = 1, position = 5, status = { stay_turns = 1 } }
    _assert_eq(status_resolve.resolve_player_status_key(game, player), "hospital",
      "stay_turns == 1 must keep the location status visible")
  end)

  -- L30 `not board or not board.get_tile`: an active location effect on a board
  -- without get_tile resolves to no key rather than indexing nil (kills `or` →
  -- `and`, which would call a nil get_tile).
  it("active location with a board lacking get_tile yields no key", function()
    local game = { board = {} }
    local player = { id = 1, position = 5, status = { stay_turns = 1 } }
    _assert_eq(status_resolve.resolve_player_status_key(game, player), nil,
      "missing board.get_tile must not produce a location status")
  end)

  -- L58 `(deity.remaining or 0) <= 0`: a deity with one remaining turn is still
  -- shown (kills `<= 0` → `<= 1`).
  it("deity with one remaining turn is shown", function()
    local game = { last_turn = {} }
    local player = {
      id = 1,
      position = 5,
      status = { deity = { type = "poor", remaining = 1 } },
    }
    _assert_eq(status_resolve.resolve_player_status_key(game, player), "poor",
      "deity remaining == 1 must still resolve to its status key")
  end)

  -- L107 `has_roadblock and has_pending`: when a roadblock stop has no pending
  -- trigger but a location effect is active, location wins over roadblock
  -- (kills `and` → `or`, which would short-circuit to "roadblock").
  it("location wins over a stopped roadblock without a pending trigger", function()
    local game = {
      board = _hospital_board(),
      last_turn = {
        player_id = 1,
        skipped = true,
        stay_turns = 2,
        move_result = { stopped_on_roadblock = true },
      },
    }
    local player = { id = 1, position = 5, status = { stay_turns = 2 } }
    _assert_eq(status_resolve.resolve_player_status_key(game, player), "hospital",
      "without a pending roadblock trigger the active location takes priority")
  end)

  -- L79 `if not deity then return 0`: deity remaining defaults to 0 when the
  -- player has no deity (kills `return 0` → `return 1`).
  it("deity remaining is 0 when the player has no deity", function()
    local player = { id = 1, status = {} }
    _assert_eq(status_resolve.resolve_remaining_value({}, player, "deity_remaining"), 0,
      "absent deity must report 0 remaining")
  end)

  -- L120 default `return 0`: an unknown remaining field reports 0 (kills the
  -- fallthrough `return 0` → `return 1`).
  it("unknown remaining field reports 0", function()
    local player = { id = 1 }
    _assert_eq(status_resolve.resolve_remaining_value({}, player, "not_a_field"), 0,
      "unrecognized remaining_field must report 0")
  end)
end)
