local status = require("src.ui.render.status3d.status")

local _has_pending_roadblock_trigger = status._M_test._has_pending_roadblock_trigger

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _build_game(overrides)
  overrides = overrides or {}
  return {
    turn = overrides.turn or {},
  }
end

local function _test_returns_false_when_game_nil()
  _assert_eq(_has_pending_roadblock_trigger(nil, { id = 1 }), false, "nil game returns false")
end

local function _test_returns_false_when_player_nil()
  _assert_eq(_has_pending_roadblock_trigger(_build_game(), nil), false, "nil player returns false")
end

local function _test_returns_false_when_player_id_nil()
  _assert_eq(_has_pending_roadblock_trigger(_build_game(), {}), false, "player with nil id returns false")
end

local function _test_returns_false_when_no_turn()
  local game = { turn = nil }
  _assert_eq(_has_pending_roadblock_trigger(game, { id = 1 }), false, "nil turn returns false")
end

local function _test_returns_true_when_action_anim_matches()
  local player = { id = 5 }
  local game = _build_game({
    turn = {
      action_anim = { kind = "roadblock_trigger", player_id = 5 },
    },
  })
  _assert_eq(_has_pending_roadblock_trigger(game, player), true, "matching action_anim returns true")
end

local function _test_returns_false_when_action_anim_wrong_player()
  local player = { id = 5 }
  local game = _build_game({
    turn = {
      action_anim = { kind = "roadblock_trigger", player_id = 99 },
    },
  })
  _assert_eq(_has_pending_roadblock_trigger(game, player), false, "wrong player_id returns false")
end

local function _test_returns_false_when_action_anim_wrong_kind()
  local player = { id = 5 }
  local game = _build_game({
    turn = {
      action_anim = { kind = "other_trigger", player_id = 5 },
    },
  })
  _assert_eq(_has_pending_roadblock_trigger(game, player), false, "wrong kind returns false")
end

local function _test_returns_true_when_queue_has_matching_entry()
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
end

local function _test_returns_false_when_queue_has_no_match()
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
end

local function _test_returns_false_when_queue_not_table()
  local player = { id = 3 }
  local game = _build_game({
    turn = {
      action_anim = nil,
      action_anim_queue = "invalid",
    },
  })
  _assert_eq(_has_pending_roadblock_trigger(game, player), false, "non-table queue returns false")
end

local function _test_returns_false_when_queue_nil()
  local player = { id = 3 }
  local game = _build_game({
    turn = {
      action_anim = nil,
      action_anim_queue = nil,
    },
  })
  _assert_eq(_has_pending_roadblock_trigger(game, player), false, "nil queue returns false")
end

return {
  name = "status3d_roadblock_crap_coverage",
  tests = {
    { name = "_test_returns_false_when_game_nil", run = _test_returns_false_when_game_nil },
    { name = "_test_returns_false_when_player_nil", run = _test_returns_false_when_player_nil },
    { name = "_test_returns_false_when_player_id_nil", run = _test_returns_false_when_player_id_nil },
    { name = "_test_returns_false_when_no_turn", run = _test_returns_false_when_no_turn },
    { name = "_test_returns_true_when_action_anim_matches", run = _test_returns_true_when_action_anim_matches },
    { name = "_test_returns_false_when_action_anim_wrong_player", run = _test_returns_false_when_action_anim_wrong_player },
    { name = "_test_returns_false_when_action_anim_wrong_kind", run = _test_returns_false_when_action_anim_wrong_kind },
    { name = "_test_returns_true_when_queue_has_matching_entry", run = _test_returns_true_when_queue_has_matching_entry },
    { name = "_test_returns_false_when_queue_has_no_match", run = _test_returns_false_when_queue_has_no_match },
    { name = "_test_returns_false_when_queue_not_table", run = _test_returns_false_when_queue_not_table },
    { name = "_test_returns_false_when_queue_nil", run = _test_returns_false_when_queue_nil },
  },
}
