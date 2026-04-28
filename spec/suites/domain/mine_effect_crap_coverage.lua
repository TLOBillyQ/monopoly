local mine_effect = require("src.rules.effects.mine")

local _find = mine_effect._M_test._find_pending_roadblock_trigger

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _test_nil_game_returns_nil()
  _assert_eq(_find(nil, { id = 1 }, 5), nil, "nil game returns nil")
end

local function _test_game_without_turn_returns_nil()
  _assert_eq(_find({}, { id = 1 }, 5), nil, "game without turn returns nil")
end

local function _test_matching_current_action_anim_returns_current()
  local current = { kind = "roadblock_trigger", player_id = 1, tile_index = 5 }
  local game = { turn = { action_anim = current } }
  _assert_eq(_find(game, { id = 1 }, 5), current, "matching current action_anim")
end

local function _test_current_anim_wrong_kind_returns_nil()
  local game = {
    turn = {
      action_anim = { kind = "mine_trigger", player_id = 1, tile_index = 5 },
    },
  }
  _assert_eq(_find(game, { id = 1 }, 5), nil, "wrong kind returns nil")
end

local function _test_current_anim_wrong_player_returns_nil()
  local game = {
    turn = {
      action_anim = { kind = "roadblock_trigger", player_id = 2, tile_index = 5 },
    },
  }
  _assert_eq(_find(game, { id = 1 }, 5), nil, "wrong player returns nil")
end

local function _test_current_anim_wrong_position_returns_nil()
  local game = {
    turn = {
      action_anim = { kind = "roadblock_trigger", player_id = 1, tile_index = 3 },
    },
  }
  _assert_eq(_find(game, { id = 1 }, 5), nil, "wrong position returns nil")
end

local function _test_found_in_queue_returns_queue_entry()
  local queued = { kind = "roadblock_trigger", player_id = 1, tile_index = 5 }
  local game = {
    turn = {
      action_anim = nil,
      action_anim_queue = { queued },
    },
  }
  _assert_eq(_find(game, { id = 1 }, 5), queued, "finds match in queue")
end

local function _test_non_matching_queue_entries_return_nil()
  local game = {
    turn = {
      action_anim = nil,
      action_anim_queue = {
        { kind = "mine_trigger", player_id = 1, tile_index = 5 },
        { kind = "roadblock_trigger", player_id = 2, tile_index = 5 },
      },
    },
  }
  _assert_eq(_find(game, { id = 1 }, 5), nil, "non-matching queue returns nil")
end

local function _test_queue_not_table_returns_nil()
  local game = {
    turn = {
      action_anim = nil,
      action_anim_queue = nil,
    },
  }
  _assert_eq(_find(game, { id = 1 }, 5), nil, "nil queue returns nil")
end

local function _test_no_current_no_queue_returns_nil()
  local game = { turn = {} }
  _assert_eq(_find(game, { id = 1 }, 5), nil, "no current and no queue returns nil")
end

return {
  name = "mine_effect_crap_coverage",
  tests = {
    { name = "nil game returns nil", run = _test_nil_game_returns_nil },
    { name = "game without turn returns nil", run = _test_game_without_turn_returns_nil },
    { name = "matching current action_anim returns current", run = _test_matching_current_action_anim_returns_current },
    { name = "current anim wrong kind returns nil", run = _test_current_anim_wrong_kind_returns_nil },
    { name = "current anim wrong player returns nil", run = _test_current_anim_wrong_player_returns_nil },
    { name = "current anim wrong position returns nil", run = _test_current_anim_wrong_position_returns_nil },
    { name = "found in queue returns queue entry", run = _test_found_in_queue_returns_queue_entry },
    { name = "queue has non-matching entries returns nil", run = _test_non_matching_queue_entries_return_nil },
    { name = "queue is not a table returns nil", run = _test_queue_not_table_returns_nil },
    { name = "no current anim and no queue returns nil", run = _test_no_current_no_queue_returns_nil },
  },
}
