-- Coverage for src.ui.view.panel_builder: player status projection and
-- turn-label caching.
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local panel_builder = require("src.ui.view.panel_builder")

-- Helper: build a minimal player stub.
local function _player(id, name, eliminated, properties)
  return {
    id = id,
    name = name,
    eliminated = eliminated or false,
    properties = properties or {},
  }
end

-- 三个无钩子 describe 拍平合并为文件级 TestPanelBuilder(_assert_eq 是自研
-- helper,语义 a == b,参数序与 LuaUnit 一致,原样保留),用例数一一对应
-- (3 + 3 + 1 = 7 例)。
TestPanelBuilder = {}

function TestPanelBuilder:test_returns_empty_status_rows_when_game_is_nil()
  local results = panel_builder.build_player_statuses(nil, nil, 0)
  _assert_eq(#results, 0, "no rows when game is nil and count is 0")
end

function TestPanelBuilder:test_handles_game_object_missing_player_cash_method_regression_for_mutate_or_and()
  -- Regression: _read_player_cash guards game == nil OR missing player_cash.
  -- When the or→and mutant replaces the guard, a game that is truthy but
  -- lacks player_cash falls through to a nil call and crashes.
  -- This test exercises the branch where game is not nil but player_cash is
  -- absent, proving the original 'or' is correct and killing the mutant.
  local game = {
    players = {
      _player("p1", "Alice"),
    },
    -- Deliberately omit player_cash so the guard on type(...) ~= "function"
    -- triggers the early return of zero.
  }
  local game_obj = { board = nil }
  local results = panel_builder.build_player_statuses(game, game_obj)
  _assert_eq(#results, 1, "one player row")
  _assert_eq(results[1].cash_value, 0, "cash_value falls back to 0 when player_cash absent")
  _assert_eq(results[1].land_count, "地块: 0", "land_count is 0")
  _assert_eq(results[1].total_assets_value, 0, "total_assets_value falls back to 0")
end

function TestPanelBuilder:test_returns_empty_fallback_row_when_a_player_slot_is_nil()
  local game = {
    players = {
      _player("p1", "Bob"),
      nil, -- empty slot
    },
  }
  game.player_cash = function(_, p)
    return p and p.id == "p1" and 500 or 0
  end
  local game_obj = { board = nil }
  local results = panel_builder.build_player_statuses(game, game_obj, 2)
  _assert_eq(#results, 2, "two rows")
  -- First row is real player.
  _assert_eq(results[1].name, "Bob", "real player name")
  _assert_eq(results[1].cash_value, 500, "real player cash from player_cash")
  -- Second row is empty fallback (from nil player → _empty_status).
  _assert_eq(results[2].name, "", "empty slot name is empty")
  _assert_eq(results[2].cash_value, nil, "empty slot has no cash_value")
  _assert_eq(results[2].eliminated, false, "empty slot not eliminated")
end

function TestPanelBuilder:test_caches_label_for_same_countdown_value()
  local label1 = panel_builder.build_turn_label(nil, 30)
  local label2 = panel_builder.build_turn_label(nil, 30)
  _assert_eq(label1, label2, "cached label returned for same second")
  _assert_eq(label1, "倒计时:30", "label format")
end

function TestPanelBuilder:test_rebuilds_label_when_seconds_change()
  local label1 = panel_builder.build_turn_label(nil, 10)
  local label2 = panel_builder.build_turn_label(nil, 20)
  _assert_eq(label1, "倒计时:10", "first label")
  _assert_eq(label2, "倒计时:20", "second label different from first")
end

function TestPanelBuilder:test_defaults_to_0_when_countdown_seconds_is_nil()
  local label = panel_builder.build_turn_label(nil, nil)
  _assert_eq(label, "倒计时:0", "defaults to 0")
end

function TestPanelBuilder:test_always_returns_fixed_auto_play_label()
  _assert_eq(panel_builder.build_auto_label(true), "托管")
  _assert_eq(panel_builder.build_auto_label(false), "托管")
end


return TestPanelBuilder
