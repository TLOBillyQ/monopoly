local test_profiles = require("src.config.testing.test_profiles")

local _profile = test_profiles._M_test._profile

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _assert_true(a, msg)
  assert(a == true, tostring(msg) .. ": expected true got " .. tostring(a))
end

local function _assert_not_nil(a, msg)
  assert(a ~= nil, tostring(msg) .. ": expected non-nil got nil")
end

local function _test_profile_meta_deep_copy()
  local original_meta = {
    group = "test_group",
    covers = { "item1", "item2" },
    nested = { key = "value" },
  }
  local result = _profile(original_meta, {})
  
  _assert_eq(result.group, "test_group", "group should be copied")
  _assert_eq(result.covers[1], "item1", "covers[1] should be copied")
  _assert_eq(result.covers[2], "item2", "covers[2] should be copied")
  
  original_meta.group = "MUTATED"
  original_meta.covers[1] = "MUTATED"
  original_meta.nested.key = "MUTATED"
  
  _assert_eq(result.group, "test_group", "group should not reflect mutation")
  _assert_eq(result.covers[1], "item1", "covers[1] should not reflect mutation")
  _assert_eq(result.nested.key, "value", "nested.key should not reflect mutation")
end

local function _test_profile_bootstrap_deep_copy()
  local original_bootstrap = {
    players = {
      [1] = { cash = 100000, position_tile_id = 5 },
      [2] = { cash = 50000 },
    },
    tiles = { [1] = { owner_player_index = 1, level = 2 } },
  }
  local result = _profile({}, original_bootstrap)
  
  _assert_eq(result.bootstrap.players[1].cash, 100000, "players[1].cash should be copied")
  _assert_eq(result.bootstrap.tiles[1].level, 2, "tiles[1].level should be copied")
  
  original_bootstrap.players[1].cash = 999999
  original_bootstrap.tiles[1].level = 99
  
  _assert_eq(result.bootstrap.players[1].cash, 100000, "players[1].cash should not reflect mutation")
  _assert_eq(result.bootstrap.tiles[1].level, 2, "tiles[1].level should not reflect mutation")
end

local function _test_profile_nil_meta_defaults_to_empty()
  local result = _profile(nil, { players = { [1] = { cash = 5000 } } })
  
  _assert_not_nil(result.bootstrap, "bootstrap should exist")
  _assert_eq(result.bootstrap.players[1].cash, 5000, "bootstrap.players[1].cash should exist")
  
  _assert_eq(result.group, nil, "group should be nil when meta is nil")
  _assert_eq(result.covers, nil, "covers should be nil when meta is nil")
end

local function _test_profile_nil_bootstrap_defaults_to_empty()
  local meta = {
    group = "my_group",
    value = "core",
    covers = { "x", "y" },
  }
  local result = _profile(meta, nil)
  
  _assert_eq(result.group, "my_group", "group should be copied from meta")
  _assert_eq(result.value, "core", "value should be copied from meta")
  _assert_not_nil(result.bootstrap, "bootstrap should exist as empty table")
  _assert_eq(result.bootstrap.players, nil, "bootstrap.players should be nil when bootstrap is nil")
end

local function _test_profile_meta_and_bootstrap_combine()
  local meta = {
    goal = "test_goal",
    owner_tests = { "test1", "test2" },
  }
  local bootstrap = {
    players = {
      [1] = { cash = 120000 },
      [2] = { cash = 100000 },
    },
  }
  local result = _profile(meta, bootstrap)
  
  _assert_eq(result.goal, "test_goal", "meta.goal should be in result")
  _assert_eq(result.owner_tests[1], "test1", "meta.owner_tests[1] should be in result")
  _assert_eq(result.bootstrap.players[1].cash, 120000, "bootstrap.players[1].cash should be in result")
  _assert_eq(result.bootstrap.players[2].cash, 100000, "bootstrap.players[2].cash should be in result")
end

local function _test_profile_bootstrap_separate_from_meta()
  local meta = {
    group = "test",
    players = { [1] = { cash = 1111 } },
  }
  local bootstrap = {
    players = { [1] = { cash = 2222 } },
  }
  local result = _profile(meta, bootstrap)
  
  _assert_eq(result.players[1].cash, 1111, "result.players should come from meta")
  _assert_eq(result.bootstrap.players[1].cash, 2222, "result.bootstrap.players should come from bootstrap")
  _assert_true(result.players ~= result.bootstrap.players, "players and bootstrap.players should be different tables")
end

return {
  _test_profile_meta_deep_copy,
  _test_profile_bootstrap_deep_copy,
  _test_profile_nil_meta_defaults_to_empty,
  _test_profile_nil_bootstrap_defaults_to_empty,
  _test_profile_meta_and_bootstrap_combine,
  _test_profile_bootstrap_separate_from_meta,
}
