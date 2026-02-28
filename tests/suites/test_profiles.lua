local support = require("TestSupport")
local app = support.app
local map_cfg = support.map_cfg
local tiles_cfg = support.tiles_cfg
local tile_state = support.tile_state

local gameplay_rules = require("Config.GameplayRules")
local test_profile_bootstrap = require("src.app.testing.TestProfileBootstrap")

local function _tile_type_lookup()
  local lookup = {}
  for _, cfg in ipairs(tiles_cfg) do
    lookup[cfg.id] = cfg.type
  end
  return lookup
end

local function _load_map_for_profile(profile_name)
  local original = gameplay_rules.test_profile
  gameplay_rules.test_profile = profile_name
  package.loaded["Config.Map"] = nil
  local map = require("Config.Map")
  gameplay_rules.test_profile = original
  package.loaded["Config.Map"] = nil
  return map
end

local function _assert_unique_path(path)
  local seen = {}
  for _, tile_id in ipairs(path) do
    assert(seen[tile_id] == nil, "duplicate tile id in path: " .. tostring(tile_id))
    seen[tile_id] = true
  end
end

local function _path_types(path, type_lookup)
  local out = {}
  for _, tile_id in ipairs(path) do
    local tile_type = type_lookup[tile_id]
    out[tile_type] = true
  end
  return out
end

local function _has_inventory_ids(player, expected_ids)
  local ids = {}
  for _, item in ipairs(player.inventory.items or {}) do
    ids[#ids + 1] = item.id
  end
  assert(#ids == #expected_ids, "inventory item count mismatch")
  for i, expected in ipairs(expected_ids) do
    assert(ids[i] == expected, "inventory item mismatch at index " .. tostring(i))
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

local function _test_default_profile_map_is_stable()
  local map = _load_map_for_profile("default")
  assert(#map.path == 45, "default profile should keep 45-tile path")
  _assert_unique_path(map.path)
end

local function _test_unknown_profile_falls_back_default_map()
  local map = _load_map_for_profile("unknown_profile_name")
  assert(#map.path == 45, "unknown profile should fallback to default map")
  _assert_unique_path(map.path)
end

local function _test_quick_profiles_map_cover_target_tiles()
  local type_lookup = _tile_type_lookup()
  local profiles = {
    ui_quick_all = { "start", "land", "market", "item", "chance", "tax", "hospital", "mountain" },
    ui_quick_choice = { "start", "land", "market", "item", "chance", "tax" },
    ui_quick_bankruptcy = { "start", "land", "market", "item", "chance", "tax", "hospital" },
  }

  for profile_name, required_types in pairs(profiles) do
    local map = _load_map_for_profile(profile_name)
    _assert_unique_path(map.path)
    local types = _path_types(map.path, type_lookup)
    for _, required in ipairs(required_types) do
      assert(types[required] == true, profile_name .. " missing tile type: " .. tostring(required))
    end
  end
end

local function _test_profile_bootstrap_quick_all_injects_resources()
  local game = _new_game()
  test_profile_bootstrap.apply(game, { profile_name = "ui_quick_all" })

  assert(game.players[1].cash == 60000, "p1 cash should match ui_quick_all")
  assert(game:player_balance(game.players[1], "金豆") == 200, "p1 jindou should match ui_quick_all")
  assert(game:player_balance(game.players[1], "乐园币") == 300, "p1 leyuanbi should match ui_quick_all")
  _has_inventory_ids(game.players[1], { 2002, 2004, 2007, 2008, 2003 })

  assert(game.players[2].cash == 80000, "p2 cash should match ui_quick_all")
end

local function _test_profile_bootstrap_quick_bankruptcy_applies_tile_override()
  local game = _new_game()
  test_profile_bootstrap.apply(game, { profile_name = "ui_quick_bankruptcy" })

  local tile = game.board:get_tile_by_id(1)
  assert(tile ~= nil, "tile 1 should exist")

  local state = tile_state(game, tile)
  assert(state.owner_id == game.players[2].id, "tile 1 owner should be player2")
  assert(state.level == 3, "tile 1 level should be 3")
  assert(game.players[2].properties[1] == true, "player2 should own tile 1")
  assert(game.players[1].cash == 3000, "p1 cash should match ui_quick_bankruptcy")
end

return {
  name = "test_profiles",
  tests = {
    { name = "default_profile_map_is_stable", run = _test_default_profile_map_is_stable },
    { name = "unknown_profile_falls_back_default_map", run = _test_unknown_profile_falls_back_default_map },
    { name = "quick_profiles_map_cover_target_tiles", run = _test_quick_profiles_map_cover_target_tiles },
    { name = "profile_bootstrap_quick_all_injects_resources", run = _test_profile_bootstrap_quick_all_injects_resources },
    { name = "profile_bootstrap_quick_bankruptcy_applies_tile_override", run = _test_profile_bootstrap_quick_bankruptcy_applies_tile_override },
  },
}
