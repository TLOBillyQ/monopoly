local _ = require("support.test_profile_support")
local test_profiles_cfg = require("src.app.testing.test_profiles")
local test_profile_resolver = require("src.app.testing.test_profile_resolver")
local items_cfg = require("src.config.content.items")

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

local function _contains(list, value)
  for _, entry in ipairs(list or {}) do
    if entry == value then
      return true
    end
  end
  return false
end

describe("runtime.test_profile_resolver", function()
  it("default_profile_map_is_stable", function()
    local map = _load_map_for_profile("default")
    assert(#map.path == 45, "default profile should keep 45-tile path")
    _assert_unique_path(map.path)
  end)

  it("all_profiles_use_default_map", function()
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
  end)

  it("unknown_profile_raises_error", function()
    local ok, err = pcall(_load_map_for_profile, "unknown_profile_name")
    assert(ok == false, "unknown profile should fail fast")
    assert(tostring(err):find("unknown test profile", 1, true) ~= nil, "error should explain unknown profile")
  end)

  it("non_default_profiles_define_p1_item_counts", function()
    local profiles = test_profile_resolver.available_profiles()
    for _, profile_name in ipairs(profiles) do
      if profile_name ~= "default" then
        local cfg = assert(test_profiles_cfg.get(profile_name), "profile config should exist")
        local p1_cfg = cfg.bootstrap and cfg.bootstrap.players and cfg.bootstrap.players[1]
        local item_counts = p1_cfg and p1_cfg.item_counts or nil
        assert(type(item_counts) == "table", "non-default profile should define p1 item_counts: " .. tostring(profile_name))
      end
    end
  end)

  it("profile_groups_are_exposed_in_priority_order", function()
    local groups = test_profile_resolver.available_groups()
    assert(groups[1] == "startup_smoke", "startup_smoke should be the first group")
    assert(_contains(groups, "combat_obstacle"), "groups should include combat_obstacle")
    assert(_contains(groups, "relocation_status"), "groups should include relocation_status")
    assert(_contains(groups, "interrupt_resume"), "groups should include interrupt_resume")
    assert(_contains(groups, "property_control"), "groups should include property_control")
    assert(_contains(groups, "economy_core"), "groups should include economy_core")
  end)

  it("profiles_in_group_returns_curated_members", function()
    local combat = test_profile_resolver.profiles_in_group("combat_obstacle", { include_default = false })
    assert(_contains(combat, "monster"), "combat group should include monster")
    assert(_contains(combat, "missile"), "combat group should include missile")
    assert(_contains(combat, "mine"), "combat group should include mine")
    assert(_contains(combat, "roadblock_hit"), "combat group should include roadblock_hit")
    assert(_contains(combat, "clear_obstacles"), "combat group should include clear_obstacles")
  end)

  it("profiles_cover_all_item_cards", function()
    local covered = {}
    for _, profile_name in ipairs(test_profile_resolver.available_profiles()) do
      if profile_name ~= "default" then
        local cfg = assert(test_profiles_cfg.get(profile_name), "profile config should exist")
        local players = cfg.bootstrap and cfg.bootstrap.players or nil
        if type(players) == "table" then
          for _, player_cfg in pairs(players) do
            local item_counts = player_cfg and player_cfg.item_counts or nil
            if type(item_counts) == "table" then
              for item_id in pairs(item_counts) do
                covered[item_id] = true
              end
            end
          end
        end
      end
    end
    for _, item in ipairs(items_cfg) do
      local item_id = item.id
      assert(covered[item_id] == true, "startup profiles should cover item id: " .. tostring(item_id))
    end
  end)
end)
