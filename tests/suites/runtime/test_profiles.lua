local support = require("support.runtime_support")
local bind_ui_runtime = support.bind_ui_runtime
local map_cfg = support.map_cfg
local tiles_cfg = support.tiles_cfg
local tile_state = support.tile_state
local build_ui_port = support.build_ui_port
local with_patches = support.with_patches
local movement = support.movement
local default_ports = require("src.turn.output.default_ports")

local constants = require("src.config.content.constants")
local board_view = require("src.ui.render.board")
local runtime_state = require("src.state.state_access.runtime_state")
local test_profiles_cfg = require("src.app.bootstrap.testing.config.test_profiles")
local test_profile_bootstrap = require("src.app.bootstrap.testing.test_profile_bootstrap")
local test_profile_resolver = require("src.app.bootstrap.testing.test_profile_resolver")
local profile_rotation = require("src.app.bootstrap.testing.profile_rotation")

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
  return require("src.app.bootstrap.compose_game").new_game(default_ports.resolve_game_opts({
    players = { "P1", "P2", "P3", "P4" },
    ai = { [2] = true, [3] = true, [4] = true },
    auto_all = false,
    map = map_cfg,
    tiles = tiles_cfg,
  }))
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
  local default_map = require("src.config.content.maps.default_map")
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
  test_profile_bootstrap.apply(game, "bankruptcy")

  local p1_expected = game.board:index_of_tile_id(35)
  local p2_expected = game.board:index_of_tile_id(39)
  assert(p1_expected ~= nil and p2_expected ~= nil, "expected tile ids should exist in default map path")
  assert(game.players[1].position == p1_expected, "p1 position should match configured position_tile_id")
  assert(game.players[2].position == p2_expected, "p2 position should match configured position_tile_id")
end

local function _test_profile_bootstrap_applies_item_counts()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "tax")

  _assert_inventory_counts(game.players[1], {
    [2002] = 1,
    [2010] = 1,
  })
  assert(game.players[1].inventory:count() == 2, "tax should grant exactly 2 items to p1")
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

local function _test_non_default_profiles_define_p1_item_counts()
  local profiles = test_profile_resolver.available_profiles()
  for _, profile_name in ipairs(profiles) do
    if profile_name ~= "default" then
      local cfg = assert(test_profiles_cfg.get(profile_name), "profile config should exist")
      local p1_cfg = cfg.bootstrap and cfg.bootstrap.players and cfg.bootstrap.players[1]
      local item_counts = p1_cfg and p1_cfg.item_counts or nil
      assert(type(item_counts) == "table", "non-default profile should define p1 item_counts: " .. tostring(profile_name))
    end
  end
end

local function _contains(list, value)
  for _, entry in ipairs(list or {}) do
    if entry == value then
      return true
    end
  end
  return false
end

local function _test_profile_groups_are_exposed_in_priority_order()
  local groups = test_profile_resolver.available_groups()
  assert(groups[1] == "startup_smoke", "startup_smoke should be the first group")
  assert(_contains(groups, "combat_obstacle"), "groups should include combat_obstacle")
  assert(_contains(groups, "relocation_status"), "groups should include relocation_status")
  assert(_contains(groups, "interrupt_resume"), "groups should include interrupt_resume")
  assert(_contains(groups, "property_control"), "groups should include property_control")
  assert(_contains(groups, "economy_core"), "groups should include economy_core")
end

local function _test_profiles_in_group_returns_curated_members()
  local combat = test_profile_resolver.profiles_in_group("combat_obstacle", { include_default = false })
  assert(_contains(combat, "monster"), "combat group should include monster")
  assert(_contains(combat, "missile"), "combat group should include missile")
  assert(_contains(combat, "mine"), "combat group should include mine")
  assert(_contains(combat, "roadblock_hit"), "combat group should include roadblock_hit")
  assert(_contains(combat, "clear_obstacles"), "combat group should include clear_obstacles")
end

local function _test_high_value_profiles_drive_default_rotation_queue()
  profile_rotation._reset_for_tests()
  local expected = test_profile_resolver.high_value_profiles()
  profile_rotation.init()
  local snapshot = profile_rotation.snapshot()
  assert(#snapshot.queue == #expected, "default rotation should use curated high value profiles")
  for index, name in ipairs(expected) do
    assert(snapshot.queue[index] == name, "rotation queue mismatch at index " .. tostring(index))
  end
  assert(_contains(snapshot.queue, "forced_move_hospital"), "high value queue should include forced_move_hospital")
  assert(_contains(snapshot.queue, "exile"), "high value queue should include exile")
  profile_rotation._reset_for_tests()
end

local function _test_bankruptcy_applies_tile_override()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "bankruptcy")

  local tile = game.board:get_tile_by_id(1)
  assert(tile ~= nil, "tile 1 should exist")

  local state = tile_state(game, tile)
  assert(state.owner_id == game.players[2].id, "tile 1 owner should be player2")
  assert(state.level == 3, "tile 1 level should be 3")
  assert(game.players[2].properties[1] == true, "player2 should own tile 1")
  assert(game.players[1].cash == 3000, "p1 cash should match bankruptcy")
end

local function _test_upgrade_build_applies_bootstrap()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "upgrade_build")

  local p1_expected = game.board:index_of_tile_id(35)
  assert(p1_expected ~= nil, "start tile id should exist in board path")
  assert(game.players[1].position == p1_expected, "p1 position should match upgrade_build")

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

local function _test_market_applies_player_position()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "market")

  local p1_expected = game.board:index_of_tile_id(27)
  assert(p1_expected ~= nil, "tile 27 should exist in board path")
  assert(game.players[1].position == p1_expected, "p1 position should match market")
end

local function _test_market_preloads_remote_dice()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "market")

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

local function _test_market_is_eight_steps_before_market()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "market")

  local market_index = game.board:index_of_tile_id(map_cfg.market_id)
  assert(market_index ~= nil, "market tile id should exist in board path")
  assert(game.players[1].position + 8 == market_index,
    "p1 should start eight steps before market after bootstrap")
end

local function _test_hospital_is_before_hospital_with_remote_dice()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "hospital")

  local p1_pos = game.players[1].position
  local hospital_idx = game.board:index_of_tile_id(36)
  assert(hospital_idx ~= nil, "hospital tile should exist in board path")
  assert(p1_pos + 1 == hospital_idx, "p1 should start one step before hospital")
  _assert_inventory_counts(game.players[1], {
    [2002] = 1,
  })
end

local function _test_mountain_is_before_mountain_with_remote_dice()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "mountain")

  local p1_pos = game.players[1].position
  local mountain_idx = game.board:index_of_tile_id(37)
  assert(mountain_idx ~= nil, "mountain tile should exist in board path")
  assert(p1_pos + 1 == mountain_idx, "p1 should start one step before mountain")
  _assert_inventory_counts(game.players[1], {
    [2002] = 1,
  })
end

local function _test_strong_card_bootstraps_rent_target()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "strong_card")

  local target_tile = assert(game.board:get_tile_by_id(12), "strong card staging target tile should exist")
  local target_state = tile_state(game, target_tile)
  local player_index = game.board:index_of_tile_id(11)

  assert(player_index ~= nil, "strong_card start tile should exist")
  assert(game.players[1].position == player_index, "strong card staging should place p1 on configured tile")
  _assert_inventory_counts(game.players[1], {
    [2001] = 1,
    [2002] = 1,
    [2009] = 1,
  })
  assert(target_state.owner_id == game.players[2].id, "strong card staging should assign target building owner")
  assert(target_state.level == 2, "strong card staging should assign target building level")
end

local function _test_monster_bootstraps_target_building()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "monster")

  local target_tile = assert(game.board:get_tile_by_id(12), "monster staging target tile should exist")
  local target_state = tile_state(game, target_tile)
  local player_index = game.board:index_of_tile_id(40)

  assert(player_index ~= nil, "monster start tile should exist")
  assert(game.players[1].position == player_index, "monster staging should place p1 on configured tile")
  _assert_inventory_counts(game.players[1], {
    [2002] = 1,
    [2008] = 1,
  })
  assert(target_state.owner_id == game.players[2].id, "monster staging should assign target building owner")
  assert(target_state.level == 2, "monster staging should assign target building level")
end

local function _test_missile_bootstraps_target_tile_and_overlays()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "missile")

  local target_tile = assert(game.board:get_tile_by_id(11), "missile staging target tile should exist")
  local target_state = tile_state(game, target_tile)
  local target_index = game.board:index_of_tile_id(11)
  local player_index = game.board:index_of_tile_id(40)

  assert(target_index ~= nil, "missile target tile should exist in board path")
  assert(player_index ~= nil, "missile start tile should exist")
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

local function _test_mine_bootstraps_positions_and_inventory()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "mine")

  assert(game.players[1].position == assert(game.board:index_of_tile_id(7)),
    "mine profile should place p1 on tile 7")
  assert(game.players[2].position == assert(game.board:index_of_tile_id(6)),
    "mine profile should place p2 on tile 6 (one step behind p1)")
  _assert_inventory_counts(game.players[1], {
    [2005] = 1,
  })
  _assert_inventory_counts(game.players[2], {
    [2002] = 1,
  })
end

local function _test_circle_bootstraps_position_and_inventory()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "circle")

  assert(game.players[1].position == assert(game.board:index_of_tile_id(15)),
    "circle should place p1 on tile 15")
  _assert_inventory_counts(game.players[1], {
    [2002] = 2,
  })
end

local function _test_forced_move_hospital_bootstraps_position_and_remote_dice()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "forced_move_hospital")

  assert(game.players[1].position == assert(game.board:index_of_tile_id(44)),
    "forced_move_hospital should place p1 on tile 44 for chance staging")
  _assert_inventory_counts(game.players[1], {
    [2002] = 1,
  })
end

local function _test_exile_bootstraps_target_pair_and_item()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "exile")

  assert(game.players[1].position == assert(game.board:index_of_tile_id(7)),
    "exile should place p1 on tile 7")
  assert(game.players[2].position == assert(game.board:index_of_tile_id(8)),
    "exile should place target p2 on tile 8")
  _assert_inventory_counts(game.players[1], {
    [2012] = 1,
  })
end

local function _test_roadblock_hit_bootstraps_forward_overlay()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "roadblock_hit")

  local target_index = assert(game.board:index_of_tile_id(8), "roadblock_hit target tile should exist")
  assert(game.players[1].position == assert(game.board:index_of_tile_id(7)),
    "roadblock_hit should place p1 one step before target")
  assert(game.board:has_roadblock(target_index) == true, "roadblock_hit should preload roadblock overlay")
  _assert_inventory_counts(game.players[1], {
    [2002] = 1,
  })
end

local function _test_clear_obstacles_bootstraps_overlay_cluster()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "clear_obstacles")

  local idx8 = assert(game.board:index_of_tile_id(8), "clear_obstacles tile 8 should exist")
  local idx9 = assert(game.board:index_of_tile_id(9), "clear_obstacles tile 9 should exist")
  assert(game.board:has_roadblock(idx8) == true, "clear_obstacles should preload first roadblock")
  assert(game.board:has_roadblock(idx9) == true, "clear_obstacles should preload second roadblock")
  assert(game.board:has_mine(idx9) == true, "clear_obstacles should preload mine on second obstacle tile")
  _assert_inventory_counts(game.players[1], {
    [2006] = 1,
  })
end

local function _test_steal_bootstraps_positions_and_inventory()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "steal")

  assert(game.players[1].position == assert(game.board:index_of_tile_id(7)),
    "steal staging should place p1 on tile 7")
  assert(game.players[2].position == assert(game.board:index_of_tile_id(8)),
    "steal staging should place p2 on tile 8")
  _assert_inventory_counts(game.players[1], {
    [2007] = 1,
  })
  _assert_inventory_counts(game.players[2], {
    [2001] = 1,
    [2010] = 1,
  })
end

local function _test_steal_one_bootstraps_positions_and_inventory()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "steal_one")

  assert(game.players[1].position == assert(game.board:index_of_tile_id(7)),
    "single-item steal staging should place p1 on tile 7")
  assert(game.players[2].position == assert(game.board:index_of_tile_id(8)),
    "single-item steal staging should place p2 on tile 8")
  _assert_inventory_counts(game.players[1], {
    [2007] = 1,
  })
  _assert_inventory_counts(game.players[2], {
    [2001] = 1,
  })
end

local function _test_steal_queue_keeps_route_and_interrupt_stable()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "steal_queue")

  local p1 = game.players[1]
  local p2 = game.players[2]
  local p3 = game.players[3]
  local p1_index = assert(game.board:index_of_tile_id(7), "tile 7 should exist in board path")
  local p2_index = assert(game.board:index_of_tile_id(8), "tile 8 should exist in board path")
  local p3_index = assert(game.board:index_of_tile_id(9), "tile 9 should exist in board path")
  local landing_tile = assert(game.board:get_tile(p1_index + 3), "steal queue landing tile should exist")

  assert(p1.position == p1_index, "queue steal staging should place p1 on tile 7")
  assert(p2.position == p2_index, "queue steal staging should place p2 on tile 8")
  assert(p3.position == p3_index, "queue steal staging should place p3 on tile 9")
  assert(landing_tile.id == 40, "queue steal staging should keep tile 40 as three-step landing tile")

  local move_result = movement.move(game, p1, 3, { branch_parity = 3, skip_market_check = true })
  local interrupt = assert(move_result.steal_interrupt, "queue steal staging should still trigger steal interrupt")

  assert(interrupt.position == p2_index, "current steal interrupt should stop on the first encountered player tile")
  assert(interrupt.remaining_steps == 2, "steal interrupt should leave two resumable steps from tile 8")
  assert(#(interrupt.encountered_ids or {}) == 1 and interrupt.encountered_ids[1] == p2.id,
    "current steal interrupt should only capture current-step targets")
end

local function _test_upgrade_build_marks_tile_render_called_for_startup_render()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "upgrade_build")

  local tile_renderer = require("src.ui.render.tile_renderer")
  local building_effects = require("src.ui.render.building_effects")
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

local function _test_strong_card_marks_tile_render_called_for_startup_render()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "strong_card")

  local tile_renderer = require("src.ui.render.tile_renderer")
  local building_effects = require("src.ui.render.building_effects")
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

local function _test_missile_marks_overlay_render_called_for_startup_render()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "missile")

  local overlay_runtime = require("src.ui.render.anim_overlay_runtime")
  local tile_renderer = require("src.ui.render.tile_renderer")
  local building_effects = require("src.ui.render.building_effects")
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
    { name = "non_default_profiles_define_p1_item_counts", run = _test_non_default_profiles_define_p1_item_counts },
    { name = "profile_groups_are_exposed_in_priority_order", run = _test_profile_groups_are_exposed_in_priority_order },
    { name = "profiles_in_group_returns_curated_members", run = _test_profiles_in_group_returns_curated_members },
    { name = "high_value_profiles_drive_default_rotation_queue", run = _test_high_value_profiles_drive_default_rotation_queue },
    { name = "bankruptcy_applies_tile_override", run = _test_bankruptcy_applies_tile_override },
    {
      name = "upgrade_build_applies_bootstrap",
      run = _test_upgrade_build_applies_bootstrap,
    },
    {
      name = "market_applies_player_position",
      run = _test_market_applies_player_position,
    },
    {
      name = "market_preloads_remote_dice",
      run = _test_market_preloads_remote_dice,
    },
    {
      name = "market_is_eight_steps_before_market",
      run = _test_market_is_eight_steps_before_market,
    },
    {
      name = "hospital_is_before_hospital_with_remote_dice",
      run = _test_hospital_is_before_hospital_with_remote_dice,
    },
    {
      name = "mountain_is_before_mountain_with_remote_dice",
      run = _test_mountain_is_before_mountain_with_remote_dice,
    },
    {
      name = "strong_card_bootstraps_rent_target",
      run = _test_strong_card_bootstraps_rent_target,
    },
    {
      name = "monster_bootstraps_target_building",
      run = _test_monster_bootstraps_target_building,
    },
    {
      name = "missile_bootstraps_target_tile_and_overlays",
      run = _test_missile_bootstraps_target_tile_and_overlays,
    },
    {
      name = "mine_bootstraps_positions_and_inventory",
      run = _test_mine_bootstraps_positions_and_inventory,
    },
    {
      name = "circle_bootstraps_position_and_inventory",
      run = _test_circle_bootstraps_position_and_inventory,
    },
    {
      name = "forced_move_hospital_bootstraps_position_and_remote_dice",
      run = _test_forced_move_hospital_bootstraps_position_and_remote_dice,
    },
    {
      name = "exile_bootstraps_target_pair_and_item",
      run = _test_exile_bootstraps_target_pair_and_item,
    },
    {
      name = "roadblock_hit_bootstraps_forward_overlay",
      run = _test_roadblock_hit_bootstraps_forward_overlay,
    },
    {
      name = "clear_obstacles_bootstraps_overlay_cluster",
      run = _test_clear_obstacles_bootstraps_overlay_cluster,
    },
    {
      name = "steal_bootstraps_positions_and_inventory",
      run = _test_steal_bootstraps_positions_and_inventory,
    },
    {
      name = "steal_one_bootstraps_positions_and_inventory",
      run = _test_steal_one_bootstraps_positions_and_inventory,
    },
    {
      name = "steal_queue_keeps_route_and_interrupt_stable",
      run = _test_steal_queue_keeps_route_and_interrupt_stable,
    },
    {
      name = "upgrade_build_marks_tile_render_called_for_startup_render",
      run = _test_upgrade_build_marks_tile_render_called_for_startup_render,
    },
    {
      name = "strong_card_marks_tile_render_called_for_startup_render",
      run = _test_strong_card_marks_tile_render_called_for_startup_render,
    },
    {
      name = "missile_marks_overlay_render_called_for_startup_render",
      run = _test_missile_marks_overlay_render_called_for_startup_render,
    },
  },
}
