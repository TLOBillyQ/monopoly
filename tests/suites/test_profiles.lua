local support = require("TestSupport")
local app = support.app
local map_cfg = support.map_cfg
local tiles_cfg = support.tiles_cfg
local tile_state = support.tile_state
local with_patches = support.with_patches

local constants = require("Config.Generated.Constants")
local test_profiles_cfg = require("src.app.testing.config.TestProfiles")
local test_profile_bootstrap = require("src.app.testing.TestProfileBootstrap")
local test_profile_resolver = require("src.app.testing.TestProfileResolver")

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
    players = { "P1", "P2" },
    ai = { [2] = true },
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
  local default_map = require("Config.Maps.DefaultMap")
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
  test_profile_bootstrap.apply(game, "items_move_control")

  local p1_expected = game.board:index_of_tile_id(35)
  local p2_expected = game.board:index_of_tile_id(39)
  assert(p1_expected ~= nil and p2_expected ~= nil, "expected tile ids should exist in default map path")
  assert(game.players[1].position == p1_expected, "p1 position should match configured position_tile_id")
  assert(game.players[2].position == p2_expected, "p2 position should match configured position_tile_id")
end

local function _test_profile_bootstrap_applies_item_counts()
  local game = _new_game()
  test_profile_bootstrap.apply(game, "items_economy_tax")

  _assert_inventory_counts(game.players[1], {
    [2001] = 1,
    [2009] = 1,
    [2010] = 1,
    [2011] = 1,
    [2014] = 1,
  })
  assert(game.players[1].inventory:count() == 5, "items_economy_tax should grant exactly 5 items to p1")
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

local function _test_all_item_group_profiles_cover_all_items_once()
  local profiles = {
    "items_move_control",
    "items_economy_tax",
    "items_target_disrupt",
    "items_deity_status",
  }
  local occur = {}
  for _, profile_name in ipairs(profiles) do
    local cfg = test_profiles_cfg.get(profile_name)
    local players = cfg and cfg.bootstrap and cfg.bootstrap.players or {}
    for _, player_cfg in pairs(players or {}) do
      local item_counts = player_cfg and player_cfg.item_counts
      if type(item_counts) == "table" then
        for item_id in pairs(item_counts) do
          occur[item_id] = (occur[item_id] or 0) + 1
        end
      end
    end
  end

  for item_id = 2001, 2019 do
    assert(occur[item_id] == 1, "all item group profiles should cover each item exactly once: " .. tostring(item_id))
  end
end

local function _test_all_item_group_profiles_respect_max_5_items_per_player()
  local profiles = {
    "items_move_control",
    "items_economy_tax",
    "items_target_disrupt",
    "items_deity_status",
  }
  for _, profile_name in ipairs(profiles) do
    local game = _new_game()
    test_profile_bootstrap.apply(game, profile_name)
    for player_index, player in ipairs(game.players) do
      assert(player.inventory:count() <= constants.inventory_slots,
        string.format("profile %s player%d exceeds max inventory slots", profile_name, player_index))
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
    { name = "all_item_group_profiles_cover_all_items_once", run = _test_all_item_group_profiles_cover_all_items_once },
    { name = "all_item_group_profiles_respect_max_5_items_per_player", run = _test_all_item_group_profiles_respect_max_5_items_per_player },
    { name = "scenario_bankruptcy_applies_tile_override", run = _test_scenario_bankruptcy_applies_tile_override },
  },
}
