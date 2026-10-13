-- luacheck: ignore 143 (genuine busted injects luassert)
local luassert = assert
local support = require("test.support.shared_support")
local function _assert_eq(actual, expected, message)
  luassert.is.equal(expected, actual, message)
end
local model_api = require("src.ui.view.init")
local board_slice = require("src.ui.view.board_slice")

describe("TestModelApi", function()

after_each(function()
  support.restore_runtime_services()
end)

-- ===== build 核心路径 =====

it("test_build_produces_model_with_meta_fields", function()
  local game = support.new_game()
  local model = model_api.build(game, nil)
  luassert.is_not_nil(model, "build should produce a model")
  luassert.truthy(type(model.turn_count) == "number", "turn count should be a number")
  luassert.truthy(model.current_player_id ~= nil, "current player id should be resolved")
end)

it("test_build_includes_board_and_panel_slices", function()
  local game = support.new_game()
  local model = model_api.build(game, nil)
  luassert.is_not_nil(model.board, "build should include board slice")
  luassert.is_not_nil(model.panel, "build should include panel slice")
end)

it("test_build_sets_finished_and_winner_from_env", function()
  local game = support.new_game()
  local env = {
    game = game,
    ui_state = nil,
    last_turn = true,
    finished = true,
    winner_name = "Alice",
  }
  local model = model_api.build(game, env)
  _assert_eq(model.finished, true, "finished should come from env")
  _assert_eq(model.winner_name, "Alice", "winner_name should come from env")
  _assert_eq(model.last_turn, true, "last_turn should come from env")
end)

it("test_build_resolves_item_slots_for_current_player", function()
  local game = support.new_game()
  local model = model_api.build(game, nil)
  luassert.is_not_nil(model.item_slots, "item_slots should be present")
  luassert.is_not_nil(model.item_slots_by_player, "item_slots_by_player should be present")
  luassert.is_not_nil(model.delegated_by_player, "delegated_by_player should be present")
end)

it("test_build_without_env_uses_default", function()
  local game = support.new_game()
  local model = model_api.build(game, nil)
  luassert.is_not_nil(model, "build should produce a model without an explicit env")
end)

-- ===== update 核心路径 =====

it("test_update_without_prev_delegates_to_build", function()
  local game = support.new_game()
  local model = model_api.update(nil, game, nil, nil)
  luassert.is_not_nil(model, "update with nil prev should call build")
end)

it("test_update_with_players_dirty_rebuilds_meta", function()
  local game = support.new_game()
  local prev = model_api.build(game, nil)
  local dirty = { players = true }
  local updated = model_api.update(prev, game, nil, dirty)
  luassert.is_not_nil(updated, "update with players dirty should produce a model")
end)

it("test_update_with_board_tiles_dirty_rebuilds_board", function()
  local game = support.new_game()
  local prev = model_api.build(game, nil)
  local dirty = { board_tiles = true }
  local updated = model_api.update(prev, game, nil, dirty)
  luassert.is_not_nil(updated.board, "board should be rebuilt when board_tiles dirty")
end)

it("test_update_with_turn_dirty_updates_choice_and_meta", function()
  local game = support.new_game()
  local prev = model_api.build(game, nil)
  local dirty = { turn = true }
  local updated = model_api.update(prev, game, nil, dirty)
  luassert.is_not_nil(updated, "update with turn dirty should produce a model")
end)

it("test_update_with_ui_dirty_flag", function()
  local game = support.new_game()
  local prev = model_api.build(game, nil)
  local dirty = { ui = true }
  local updated = model_api.update(prev, game, nil, dirty)
  luassert.is_not_nil(updated, "update with ui dirty should succeed")
end)

it("test_update_with_market_dirty_refreshes_choice", function()
  local game = support.new_game()
  local prev = model_api.build(game, nil)
  local dirty = { market = true }
  local updated = model_api.update(prev, game, nil, dirty)
  luassert.is_not_nil(updated, "update with market dirty should succeed")
end)

it("test_update_with_turn_countdown_dirty_updates_panel", function()
  local game = support.new_game()
  local prev = model_api.build(game, nil)
  local dirty = { turn_countdown = true }
  local updated = model_api.update(prev, game, nil, dirty)
  luassert.is_not_nil(updated.panel, "panel should be updated")
end)

it("test_update_sets_board_tile_count", function()
  local game = support.new_game()
  local prev = model_api.build(game, nil)
  local updated = model_api.update(prev, game, nil, {})
  _assert_eq(updated.board_tile_count, board_slice.tile_count(), "board_tile_count should be set")
end)

it("test_update_with_inventory_dirty_triggers_slots_refresh", function()
  local game = support.new_game()
  local prev = model_api.build(game, nil)
  local dirty = { inventory = true }
  local updated = model_api.update(prev, game, nil, dirty)
  luassert.is_not_nil(updated, "update with inventory dirty should succeed")
end)

it("test_update_without_env_creates_default", function()
  local game = support.new_game()
  local prev = model_api.build(game, nil)
  local updated = model_api.update(prev, game, nil, {})
  luassert.is_not_nil(updated, "update without env should succeed")
end)

end)
