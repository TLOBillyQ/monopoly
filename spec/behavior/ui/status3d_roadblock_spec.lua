local signals = require("src.ui.render.status3d.status_signals")

local _has_pending_roadblock_trigger = signals.has_pending_roadblock_trigger

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _build_game(overrides)
  overrides = overrides or {}
  return {
    turn = overrides.turn or {},
  }
end

describe("status3d_roadblock_crap_coverage", function()
  it("_test_returns_false_when_game_nil", function()
    _assert_eq(_has_pending_roadblock_trigger(nil, { id = 1 }), false, "nil game returns false")
  end)

  it("_test_returns_false_when_player_nil", function()
    _assert_eq(_has_pending_roadblock_trigger(_build_game(), nil), false, "nil player returns false")
  end)

  it("_test_returns_false_when_player_id_nil", function()
    _assert_eq(_has_pending_roadblock_trigger(_build_game(), {}), false, "player with nil id returns false")
  end)

  it("_test_returns_false_when_no_turn", function()
    local game = { turn = nil }
    _assert_eq(_has_pending_roadblock_trigger(game, { id = 1 }), false, "nil turn returns false")
  end)

  it("_test_returns_true_when_action_anim_matches", function()
    local player = { id = 5 }
    local game = _build_game({
      turn = {
        action_anim = { kind = "roadblock_trigger", player_id = 5 },
      },
    })
    _assert_eq(_has_pending_roadblock_trigger(game, player), true, "matching action_anim returns true")
  end)

  it("_test_returns_false_when_action_anim_wrong_player", function()
    local player = { id = 5 }
    local game = _build_game({
      turn = {
        action_anim = { kind = "roadblock_trigger", player_id = 99 },
      },
    })
    _assert_eq(_has_pending_roadblock_trigger(game, player), false, "wrong player_id returns false")
  end)

  it("_test_returns_false_when_action_anim_wrong_kind", function()
    local player = { id = 5 }
    local game = _build_game({
      turn = {
        action_anim = { kind = "other_trigger", player_id = 5 },
      },
    })
    _assert_eq(_has_pending_roadblock_trigger(game, player), false, "wrong kind returns false")
  end)

  it("_test_returns_true_when_queue_has_matching_entry", function()
    local player = { id = 3 }
    local game = _build_game({
      turn = {
        action_anim = nil,
        action_anim_queue = {
          { kind = "other", player_id = 3 },
          { kind = "roadblock_trigger", player_id = 3 },
        },
      },
    })
    _assert_eq(_has_pending_roadblock_trigger(game, player), true, "matching queue entry returns true")
  end)

  it("_test_returns_false_when_queue_has_no_match", function()
    local player = { id = 3 }
    local game = _build_game({
      turn = {
        action_anim = nil,
        action_anim_queue = {
          { kind = "roadblock_trigger", player_id = 99 },
        },
      },
    })
    _assert_eq(_has_pending_roadblock_trigger(game, player), false, "no matching queue entry returns false")
  end)

  it("_test_returns_false_when_queue_not_table", function()
    local player = { id = 3 }
    local game = _build_game({
      turn = {
        action_anim = nil,
        action_anim_queue = "invalid",
      },
    })
    _assert_eq(_has_pending_roadblock_trigger(game, player), false, "non-table queue returns false")
  end)

  it("_test_returns_false_when_queue_nil", function()
    local player = { id = 3 }
    local game = _build_game({
      turn = {
        action_anim = nil,
        action_anim_queue = nil,
      },
    })
    _assert_eq(_has_pending_roadblock_trigger(game, player), false, "nil queue returns false")
  end)
end)
