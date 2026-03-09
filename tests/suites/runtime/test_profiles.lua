local support = require("TestSupport")
local app = support.app
local bind_ui_runtime = support.bind_ui_runtime
local map_cfg = support.map_cfg
local tiles_cfg = support.tiles_cfg
local tile_state = support.tile_state
local build_ui_port = support.build_ui_port
local with_patches = support.with_patches

local constants = require("Config.generated.constants")
local board_view = require("src.presentation.view.render.board")
local runtime_state = require("src.core.state_access.runtime_state")
local test_profiles_cfg = require("src.app.testing.config.test_profiles")
local test_profile_bootstrap = require("src.app.testing.test_profile_bootstrap")
local test_profile_resolver = require("src.app.testing.test_profile_resolver")

local function _load_map_for_profile(profile_name)
  return test_profile_resolver.resolve_map(profile_name)
end

local function _assert_unique_path(path)
  local seen = {}
  for _, tile_id in ipairs(path) do
    assert(seen[tile_id] == nil, "duplicate tile id in path: " .. tostring(tile_id))
    seen[tile_id] = true
  end
end

local function _new_game()
  return app:new({
    players = { "P1", "P2", "P3", "P4" },
    ai = { [2] = true, [3] = true, [4] = true },
    auto_all = false,
    map = map_cfg,
    tiles = tiles_cfg,
  })
end

local function _inventory_counts_by_id(player)
  local counts = {}
  for _, item in ipairs(player.inventory.items or {}) do
    counts[item.id] = (counts[item.id] or 0) + 1
  end
  return counts
end

local function _assert_inventory_counts(player, expected_counts)
  local actual = _inventory_counts_by_id(player)
  local actual_total = 0
  for _, count in pairs(actual) do
    actual_total = actual_total + count
  end

  local expected_total = 0
  for item_id, count in pairs(expected_counts) do
    expected_total = expected_total + count
    assert(actual[item_id] == count, "item count mismatch for " .. tostring(item_id))
  end
  assert(actual_total == expected_total, "inventory total mismatch")
end

local function _test_default_profile_map_is_stable()
  local map = _load_map_for_profile("default")
  assert(#map.path == 45, "default profile should keep 45-tile path")
  _assert_unique_path(map.path)
end

local function _test_all_profiles_use_default_map()
  local default_map = require("Config.maps.default_map")
  local names = test_profile_resolver.available_profiles()
  for _, name in ipairs(names) do
    local map = _load_map_for_profile(name)
    assert(#map.path == #default_map.path, "profile map path length should match default: " .. tostring(name))
    for i = 1, #default_map.path do
      assert(map.path[i] == default_map.path[i], "profile map path mismatch at index " .. tostring(i))
    end
    assert(map.start_id == default_map.start_id, "profile start_id should match default: " .. tostring(name))
    assert(map.market_id == default_map.market_id, "profile market_id should match default: " .. tostring(name))
  end
end

local function _test_unknown_profile_raises_error()
  local ok, err = pcall(_load_map_for_profile, "unknown_profile_name")
  assert(ok == false, "unknown profile should fail fast")
  assert(tostring(err):find("unknown test profile", 1, true) ~= nil, "error should explain unknown profile")
end

local function _test_profile_bootstrap_applies_player_position_by_tile_id()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "scenario_bankruptcy")

  local p1_expected = game.board:index_of_tile_id(35)
  local p2_expected = game.board:index_of_tile_id(39)
  assert(p1_expected ~= nil and p2_expected ~= nil, "expected tile ids should exist in default map path")
  assert(game.players[1].position == p1_expected, "p1 position should match configured position_tile_id")
  assert(game.players[2].position == p2_expected, "p2 position should match configured position_tile_id")
end

local function _test_profile_bootstrap_applies_item_counts()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "scenario_tax_survive")

  _assert_inventory_counts(game.players[1], {
    [2002] = 1,
    [2010] = 1,
  })
  assert(game.players[1].inventory:count() == 2, "scenario_tax_survive should grant exactly 2 items to p1")
end

local function _test_profile_bootstrap_rejects_item_count_over_inventory_limit()
  local game = _new_game()
  local ok, err = pcall(function()
    with_patches({
      {
        target = test_profile_resolver,
        key = "resolve_bootstrap",
        value = function()
          return {
            players = {
              [1] = {
                item_counts = {
                  [2001] = 2,
                  [2002] = 2,
                  [2003] = 2,
                },
              },
            },
          }
        end,
      },
    }, function()
      test_profile_bootstrap.apply(game, "default")
    end)
  end)
  assert(ok == false, "item_counts exceeding inventory limit should fail fast")
  assert(tostring(err):find("item_counts exceeds inventory limit", 1, true) ~= nil,
    "error should explain inventory limit breach")
end

local function _test_non_default_profiles_are_scenarios_with_remote_dice()
  local profiles = test_profile_resolver.available_profiles()
  for _, profile_name in ipairs(profiles) do
    if profile_name ~= "default" then
      assert(profile_name:find("scenario_", 1, true) == 1,
        "non-default profiles should keep scenario_ prefix: " .. tostring(profile_name))
      local cfg = assert(test_profiles_cfg.get(profile_name), "profile config should exist")
      local p1_cfg = cfg.bootstrap and cfg.bootstrap.players and cfg.bootstrap.players[1]
      local item_counts = p1_cfg and p1_cfg.item_counts or nil
      assert(type(item_counts) == "table", "scenario profile should define p1 item_counts: " .. tostring(profile_name))
      assert(item_counts[2002] == 1, "scenario profile should preload one remote dice: " .. tostring(profile_name))
    end
  end
end

local function _test_scenario_bankruptcy_applies_tile_override()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "scenario_bankruptcy")

  local tile = game.board:get_tile_by_id(1)
  assert(tile ~= nil, "tile 1 should exist")

  local state = tile_state(game, tile)
  assert(state.owner_id == game.players[2].id, "tile 1 owner should be player2")
  assert(state.level == 3, "tile 1 level should be 3")
  assert(game.players[2].properties[1] == true, "player2 should own tile 1")
  assert(game.players[1].cash == 3000, "p1 cash should match scenario_bankruptcy")
end

local function _test_scenario_upgrade_building_render_applies_bootstrap()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "scenario_upgrade_building_render")

  local p1_expected = game.board:index_of_tile_id(35)
  assert(p1_expected ~= nil, "start tile id should exist in board path")
  assert(game.players[1].position == p1_expected, "p1 position should match scenario_upgrade_building_render")

  local tile = game.board:get_tile_by_id(1)
  assert(tile ~= nil, "tile 1 should exist")
  local state = tile_state(game, tile)
  assert(state.owner_id == game.players[1].id, "tile 1 owner should be player1")
  assert(state.level == 0, "tile 1 level should be 0")
  assert(game.players[1].properties[1] == true, "player1 should own tile 1")

  _assert_inventory_counts(game.players[1], {
    [2002] = 1,
  })
end

local function _test_scenario_market_staging_applies_player_position()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "scenario_market_staging")

  local p1_expected = game.board:index_of_tile_id(27)
  assert(p1_expected ~= nil, "tile 27 should exist in board path")
  assert(game.players[1].position == p1_expected, "p1 position should match scenario_market_staging")
end

local function _test_scenario_market_staging_preloads_remote_dice()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "scenario_market_staging")

  _assert_inventory_counts(game.players[1], {
    [2002] = 1,
  })
end

local function _new_render_state(game)
  local state = {
    game = game,
    ui = build_ui_port().ui,
    board_scene = {
      tiles = {},
      buildings = {},
      building_txt = {},
      building_unit_groups = {},
      ground = {
        get_position = function()
          return math.Vector3(0, 0, 0)
        end,
      },
    },
    tile_units = {},
    tile_positions = {},
    tile_spacing = 1,
    player_units = {},
    player_units_missing = false,
  }
  bind_ui_runtime(state)
  runtime_state.ensure_all(state)
  for index = 1, #game.board.path do
    local tile_pos = math.Vector3(index, 0, 0)
    state.board_scene.tiles[index] = {
      get_position = function()
        return tile_pos
      end,
    }
    state.tile_units[index] = state.board_scene.tiles[index]
    state.tile_positions[index] = tile_pos
    state.board_scene.buildings[index] = {
      get_position = function()
        return math.Vector3(index, 1, 0)
      end,
    }
    state.board_scene.building_txt[index] = {
      set_billboard_text = function() end,
    }
  end
  for _, player in ipairs(game.players) do
    state.player_units[player.id] = {
      set_position = function() end,
    }
  end
  return state
end

local function _render_profile_startup(game)
  local state = _new_render_state(game)
  local ui_model = {
    board = {
      tiles = {},
      tile_states = game.board.tile_lookup,
      players = game.players,
      tile_count = #game.board.path,
      phase = game.turn and game.turn.phase or "start",
      move_anim = nil,
      move_followup_pending = false,
      vehicle_resync_seq = 0,
    },
  }
  for index, tile in ipairs(game.board.path) do
    ui_model.board.tiles[index] = {
      id = tile.id,
      type = tile.type,
    }
  end
  local board_runtime = runtime_state.ensure_board_runtime(state)
  for _, player in ipairs(game.players) do
    board_runtime.board_last_positions[player.id] = tostring(player.position) .. ":" .. tostring(player.eliminated and 1 or 0)
  end
  board_runtime.board_last_vehicle_resync_seq = ui_model.board.vehicle_resync_seq
  board_view.refresh(state, ui_model, function() end, function() return "test_profiles" end)
  return state
end

local function _test_scenario_market_staging_is_eight_steps_before_market()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "scenario_market_staging")

  local market_index = game.board:index_of_tile_id(map_cfg.market_id)
  assert(market_index ~= nil, "market tile id should exist in board path")
  assert(game.players[1].position + 8 == market_index,
    "p1 should start eight steps before market after bootstrap")
end

local function _test_scenario_hospital_staging_is_before_hospital_with_remote_dice()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "scenario_hospital_staging")

  local p1_pos = game.players[1].position
  local hospital_idx = game.board:index_of_tile_id(36)
  assert(hospital_idx ~= nil, "hospital tile should exist in board path")
  assert(p1_pos + 1 == hospital_idx, "p1 should start one step before hospital")
  _assert_inventory_counts(game.players[1], {
    [2002] = 1,
  })
end

local function _test_scenario_mountain_staging_is_before_mountain_with_remote_dice()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "scenario_mountain_staging")

  local p1_pos = game.players[1].position
  local mountain_idx = game.board:index_of_tile_id(37)
  assert(mountain_idx ~= nil, "mountain tile should exist in board path")
  assert(p1_pos + 1 == mountain_idx, "p1 should start one step before mountain")
  _assert_inventory_counts(game.players[1], {
    [2002] = 1,
  })
end

local function _test_scenario_strong_card_staging_bootstraps_rent_target()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "scenario_strong_card_staging")

  local target_tile = assert(game.board:get_tile_by_id(12), "strong card staging target tile should exist")
  local target_state = tile_state(game, target_tile)
  local player_index = game.board:index_of_tile_id(11)

  assert(player_index ~= nil, "scenario_strong_card_staging start tile should exist")
  assert(game.players[1].position == player_index, "strong card staging should place p1 on configured tile")
  _assert_inventory_counts(game.players[1], {
    [2001] = 1,
    [2002] = 1,
    [2009] = 1,
  })
  assert(target_state.owner_id == game.players[2].id, "strong card staging should assign target building owner")
  assert(target_state.level == 2, "strong card staging should assign target building level")
end

local function _test_scenario_monster_staging_bootstraps_target_building()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "scenario_monster_staging")

  local target_tile = assert(game.board:get_tile_by_id(12), "monster staging target tile should exist")
  local target_state = tile_state(game, target_tile)
  local player_index = game.board:index_of_tile_id(40)

  assert(player_index ~= nil, "scenario_monster_staging start tile should exist")
  assert(game.players[1].position == player_index, "monster staging should place p1 on configured tile")
  _assert_inventory_counts(game.players[1], {
    [2002] = 1,
    [2008] = 1,
  })
  assert(target_state.owner_id == game.players[2].id, "monster staging should assign target building owner")
  assert(target_state.level == 2, "monster staging should assign target building level")
end

local function _test_scenario_missile_staging_bootstraps_target_tile_and_overlays()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "scenario_missile_staging")

  local target_tile = assert(game.board:get_tile_by_id(11), "missile staging target tile should exist")
  local target_state = tile_state(game, target_tile)
  local target_index = game.board:index_of_tile_id(11)
  local player_index = game.board:index_of_tile_id(40)

  assert(target_index ~= nil, "scenario_missile_staging target tile should exist in board path")
  assert(player_index ~= nil, "scenario_missile_staging start tile should exist")
  assert(game.players[1].position == player_index, "missile staging should place p1 on configured tile")
  _assert_inventory_counts(game.players[1], {
    [2002] = 1,
    [2013] = 1,
  })
  assert(target_state.owner_id == game.players[2].id, "missile staging should assign target building owner")
  assert(target_state.level == 2, "missile staging should assign target building level")
  assert(game.board:has_roadblock(target_index) == true, "missile staging should place roadblock on target tile")
  assert(game.board:has_mine(target_index) == true, "missile staging should place mine on target tile")
  assert(game.players[2].position == target_index, "missile staging should place occupant on target tile")
end

local function _test_scenario_upgrade_building_render_marks_tile_render_called_for_startup_render()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "scenario_upgrade_building_render")

  local tile_renderer = require("src.presentation.view.render.tile_renderer")
  local building_effects = require("src.presentation.view.render.building_effects")
  local rendered_tile_ids = {}
  local rendered_building_tile_ids = {}

  with_patches({
    {
      target = tile_renderer,
      key = "render_tile",
      value = function(_, tile_id)
        rendered_tile_ids[#rendered_tile_ids + 1] = tile_id
        return true
      end,
    },
    {
      target = building_effects,
      key = "spawn_upgrade_building_units",
      value = function(_, _, building_index)
        local tile = game.board:get_tile(building_index)
        rendered_building_tile_ids[#rendered_building_tile_ids + 1] = tile and tile.id or nil
        return true
      end,
    },
  }, function()
    _render_profile_startup(game)
  end)

  assert(rendered_tile_ids[1] == 1, "startup render should render configured tile")
  assert(#rendered_tile_ids == 1, "startup render should only render flagged tiles")
  assert(#rendered_building_tile_ids == 0, "level 0 tile should not spawn startup building render")
end

local function _test_scenario_strong_card_staging_marks_tile_render_called_for_startup_render()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "scenario_strong_card_staging")

  local tile_renderer = require("src.presentation.view.render.tile_renderer")
  local building_effects = require("src.presentation.view.render.building_effects")
  local rendered_tile_ids = {}
  local rendered_building_tile_ids = {}

  with_patches({
    {
      target = tile_renderer,
      key = "render_tile",
      value = function(_, tile_id)
        rendered_tile_ids[#rendered_tile_ids + 1] = tile_id
        return true
      end,
    },
    {
      target = building_effects,
      key = "spawn_upgrade_building_units",
      value = function(_, _, building_index)
        local tile = game.board:get_tile(building_index)
        rendered_building_tile_ids[#rendered_building_tile_ids + 1] = tile and tile.id or nil
        return true
      end,
    },
  }, function()
    _render_profile_startup(game)
  end)

  assert(rendered_tile_ids[1] == 12, "startup render should render strong card staging target tile")
  assert(#rendered_tile_ids == 1, "startup render should only render flagged tile")
  assert(rendered_building_tile_ids[1] == 12, "startup render should spawn building for strong card staging target tile")
  assert(#rendered_building_tile_ids == 1, "startup render should only spawn flagged building")
end

local function _test_scenario_missile_staging_marks_overlay_render_called_for_startup_render()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "scenario_missile_staging")

  local overlay_runtime = require("src.presentation.view.render.anim_overlay_runtime")
  local tile_renderer = require("src.presentation.view.render.tile_renderer")
  local building_effects = require("src.presentation.view.render.building_effects")
  local overlay_calls = {}
  local rendered_tile_ids = {}
  local rendered_building_tile_ids = {}

  with_patches({
    {
      target = overlay_runtime,
      key = "spawn_overlay",
      value = function(_, kind, tile_index)
        overlay_calls[#overlay_calls + 1] = { kind = kind, tile_index = tile_index }
        return true
      end,
    },
    {
      target = tile_renderer,
      key = "render_tile",
      value = function(_, tile_id)
        rendered_tile_ids[#rendered_tile_ids + 1] = tile_id
        return true
      end,
    },
    {
      target = building_effects,
      key = "spawn_upgrade_building_units",
      value = function(_, _, building_index)
        local tile = game.board:get_tile(building_index)
        rendered_building_tile_ids[#rendered_building_tile_ids + 1] = tile and tile.id or nil
        return true
      end,
    },
  }, function()
    _render_profile_startup(game)
  end)

  local target_index = assert(game.board:index_of_tile_id(11), "missile staging target tile should exist in board path")
  assert(rendered_tile_ids[1] == 11, "startup render should render flagged tile before overlay")
  assert(#rendered_tile_ids == 1, "startup render should only render flagged tile")
  assert(rendered_building_tile_ids[1] == 11, "startup render should spawn building for flagged tile with level")
  assert(#rendered_building_tile_ids == 1, "startup render should only spawn flagged building")
  assert(#overlay_calls == 2, "startup render should spawn both flagged overlays")
  local kinds = {
    [overlay_calls[1].kind] = true,
    [overlay_calls[2].kind] = true,
  }
  local indices = {
    [overlay_calls[1].tile_index] = true,
    [overlay_calls[2].tile_index] = true,
  }
  assert(kinds.roadblock == true, "startup render should spawn roadblock overlay")
  assert(kinds.mine == true, "startup render should spawn mine overlay")
  assert(indices[target_index] == true, "startup overlay render should target configured tile index")
end

return {
  name = "test_profiles",
  tests = {
    { name = "default_profile_map_is_stable", run = _test_default_profile_map_is_stable },
    { name = "all_profiles_use_default_map", run = _test_all_profiles_use_default_map },
    { name = "unknown_profile_raises_error", run = _test_unknown_profile_raises_error },
    { name = "profile_bootstrap_applies_player_position_by_tile_id", run = _test_profile_bootstrap_applies_player_position_by_tile_id },
    { name = "profile_bootstrap_applies_item_counts", run = _test_profile_bootstrap_applies_item_counts },
    {
      name = "profile_bootstrap_rejects_item_count_over_inventory_limit",
      run = _test_profile_bootstrap_rejects_item_count_over_inventory_limit,
    },
    { name = "non_default_profiles_are_scenarios_with_remote_dice", run = _test_non_default_profiles_are_scenarios_with_remote_dice },
    { name = "scenario_bankruptcy_applies_tile_override", run = _test_scenario_bankruptcy_applies_tile_override },
    {
      name = "scenario_upgrade_building_render_applies_bootstrap",
      run = _test_scenario_upgrade_building_render_applies_bootstrap,
    },
    {
      name = "scenario_market_staging_applies_player_position",
      run = _test_scenario_market_staging_applies_player_position,
    },
    {
      name = "scenario_market_staging_preloads_remote_dice",
      run = _test_scenario_market_staging_preloads_remote_dice,
    },
    {
      name = "scenario_market_staging_is_eight_steps_before_market",
      run = _test_scenario_market_staging_is_eight_steps_before_market,
    },
    {
      name = "scenario_hospital_staging_is_before_hospital_with_remote_dice",
      run = _test_scenario_hospital_staging_is_before_hospital_with_remote_dice,
    },
    {
      name = "scenario_mountain_staging_is_before_mountain_with_remote_dice",
      run = _test_scenario_mountain_staging_is_before_mountain_with_remote_dice,
    },
    {
      name = "scenario_strong_card_staging_bootstraps_rent_target",
      run = _test_scenario_strong_card_staging_bootstraps_rent_target,
    },
    {
      name = "scenario_monster_staging_bootstraps_target_building",
      run = _test_scenario_monster_staging_bootstraps_target_building,
    },
    {
      name = "scenario_missile_staging_bootstraps_target_tile_and_overlays",
      run = _test_scenario_missile_staging_bootstraps_target_tile_and_overlays,
    },
    {
      name = "scenario_upgrade_building_render_marks_tile_render_called_for_startup_render",
      run = _test_scenario_upgrade_building_render_marks_tile_render_called_for_startup_render,
    },
    {
      name = "scenario_strong_card_staging_marks_tile_render_called_for_startup_render",
      run = _test_scenario_strong_card_staging_marks_tile_render_called_for_startup_render,
    },
    {
      name = "scenario_missile_staging_marks_overlay_render_called_for_startup_render",
      run = _test_scenario_missile_staging_marks_overlay_render_called_for_startup_render,
    },
  },
}
