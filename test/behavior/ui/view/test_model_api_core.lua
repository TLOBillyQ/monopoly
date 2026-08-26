local lu = require("luaunit")
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local model_api = require("src.ui.view.init")
local board_slice = require("src.ui.view.board_slice")

TestModelApi = {}

function TestModelApi:tearDown()
  support.restore_runtime_services()
end

-- ===== build 核心路径 =====

function TestModelApi:test_build_produces_model_with_meta_fields()
  local game = support.new_game()
  local model = model_api.build(game, nil)
  lu.assertNotNil(model, "build should produce a model")
  lu.assertEvalToTrue(type(model.turn_count) == "number", "turn count should be a number")
  lu.assertEvalToTrue(model.current_player_id ~= nil, "current player id should be resolved")
end

function TestModelApi:test_build_includes_board_and_panel_slices()
  local game = support.new_game()
  local model = model_api.build(game, nil)
  lu.assertNotNil(model.board, "build should include board slice")
  lu.assertNotNil(model.panel, "build should include panel slice")
end

function TestModelApi:test_build_sets_finished_and_winner_from_env()
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
end

function TestModelApi:test_build_resolves_item_slots_for_current_player()
  local game = support.new_game()
  local model = model_api.build(game, nil)
  lu.assertNotNil(model.item_slots, "item_slots should be present")
  lu.assertNotNil(model.item_slots_by_player, "item_slots_by_player should be present")
  lu.assertNotNil(model.delegated_by_player, "delegated_by_player should be present")
end

function TestModelApi:test_build_without_env_uses_default()
  local game = support.new_game()
  local model = model_api.build(game, nil)
  lu.assertNotNil(model, "build should produce a model without an explicit env")
end

-- ===== update 核心路径 =====

function TestModelApi:test_update_without_prev_delegates_to_build()
  local game = support.new_game()
  local model = model_api.update(nil, game, nil, nil)
  lu.assertNotNil(model, "update with nil prev should call build")
end

function TestModelApi:test_update_with_players_dirty_rebuilds_meta()
  local game = support.new_game()
  local prev = model_api.build(game, nil)
  local dirty = { players = true }
  local updated = model_api.update(prev, game, nil, dirty)
  lu.assertNotNil(updated, "update with players dirty should produce a model")
end

function TestModelApi:test_update_with_board_tiles_dirty_rebuilds_board()
  local game = support.new_game()
  local prev = model_api.build(game, nil)
  local dirty = { board_tiles = true }
  local updated = model_api.update(prev, game, nil, dirty)
  lu.assertNotNil(updated.board, "board should be rebuilt when board_tiles dirty")
end

function TestModelApi:test_update_with_turn_dirty_updates_choice_and_meta()
  local game = support.new_game()
  local prev = model_api.build(game, nil)
  local dirty = { turn = true }
  local updated = model_api.update(prev, game, nil, dirty)
  lu.assertNotNil(updated, "update with turn dirty should produce a model")
end

function TestModelApi:test_update_with_ui_dirty_flag()
  local game = support.new_game()
  local prev = model_api.build(game, nil)
  local dirty = { ui = true }
  local updated = model_api.update(prev, game, nil, dirty)
  lu.assertNotNil(updated, "update with ui dirty should succeed")
end

function TestModelApi:test_update_with_market_dirty_refreshes_choice()
  local game = support.new_game()
  local prev = model_api.build(game, nil)
  local dirty = { market = true }
  local updated = model_api.update(prev, game, nil, dirty)
  lu.assertNotNil(updated, "update with market dirty should succeed")
end

function TestModelApi:test_update_with_turn_countdown_dirty_updates_panel()
  local game = support.new_game()
  local prev = model_api.build(game, nil)
  local dirty = { turn_countdown = true }
  local updated = model_api.update(prev, game, nil, dirty)
  lu.assertNotNil(updated.panel, "panel should be updated")
end

function TestModelApi:test_update_sets_board_tile_count()
  local game = support.new_game()
  local prev = model_api.build(game, nil)
  local updated = model_api.update(prev, game, nil, {})
  _assert_eq(updated.board_tile_count, board_slice.tile_count(), "board_tile_count should be set")
end

function TestModelApi:test_update_with_inventory_dirty_triggers_slots_refresh()
  local game = support.new_game()
  local prev = model_api.build(game, nil)
  local dirty = { inventory = true }
  local updated = model_api.update(prev, game, nil, dirty)
  lu.assertNotNil(updated, "update with inventory dirty should succeed")
end

function TestModelApi:test_update_without_env_creates_default()
  local game = support.new_game()
  local prev = model_api.build(game, nil)
  local updated = model_api.update(prev, game, nil, {})
  lu.assertNotNil(updated, "update without env should succeed")
end

return TestModelApi
