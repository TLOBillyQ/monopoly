local support = require("support.runtime_support")
local with_patches = support.with_patches
local app = support.app
local startup_policy = require("src.app.bootstrap.startup_policy")
local game_startup = require("src.app.bootstrap.game_startup")
local runtime_ports = require("src.core.ports.runtime_ports")
local test_profile_bootstrap = require("src.app.testing.test_profile_bootstrap")
local runtime_refs = require("Config.runtime_refs")

local function _build_role(role_id)
  return {
    id = role_id,
    get_roleid = function()
      return role_id
    end,
  }
end

local function _assert_unique_unit_keys(role_roster, expected_count)
  local seen = {}
  local synthetic_count = 0
  for _, entry in ipairs(role_roster or {}) do
    if entry and entry.synthetic == true then
      synthetic_count = synthetic_count + 1
      assert(entry.unit_key ~= nil, "synthetic entry should provide unit_key")
      assert(seen[entry.unit_key] == nil, "synthetic unit_key should be unique per match")
      seen[entry.unit_key] = true
    end
  end
  assert(synthetic_count == expected_count, "unexpected synthetic entry count")
end

local function _assert_synthetic_avatar_keys(entries, expected_slots)
  local expected_by_slot = {}
  for _, slot_index in ipairs(expected_slots or {}) do
    local expected_image_key = runtime_refs.images["AI" .. tostring(slot_index)]
    assert(expected_image_key ~= nil, "missing runtime ref for AI slot: " .. tostring(slot_index))
    expected_by_slot[slot_index] = expected_image_key
  end

  for slot_index, entry in ipairs(entries or {}) do
    if entry and entry.synthetic == true then
      local expected_image_key = expected_by_slot[slot_index]
      assert(expected_image_key ~= nil, "unexpected synthetic slot: " .. tostring(slot_index))
      assert(entry.avatar_image_key == expected_image_key,
        "synthetic slot should use matching AI avatar ref: " .. tostring(slot_index))
      expected_by_slot[slot_index] = nil
    end
  end

  for slot_index, remaining in pairs(expected_by_slot) do
    assert(remaining == nil, "missing synthetic avatar assertion for slot: " .. tostring(slot_index))
  end
end

local function _assert_startup_synthetic_specs_have_slot_avatars(specs, expected_slots)
  local expected_by_player_id = {}
  for _, slot_index in ipairs(expected_slots or {}) do
    expected_by_player_id[-slot_index] = runtime_refs.images["AI" .. tostring(slot_index)]
  end

  for _, spec in ipairs(specs or {}) do
    if spec and spec.player_id ~= nil then
      local expected_image_key = expected_by_player_id[spec.player_id]
      assert(expected_image_key ~= nil, "unexpected synthetic player id: " .. tostring(spec.player_id))
      assert(spec.avatar_image_key == expected_image_key,
        "startup synthetic spec should keep slot avatar image key")
      expected_by_player_id[spec.player_id] = nil
    end
  end

  for player_id, remaining in pairs(expected_by_player_id) do
    assert(remaining == nil, "missing synthetic startup spec for player id: " .. tostring(player_id))
  end
end

local function _test_startup_policy_defaults_to_release()
  with_patches({
    { key = "RELEASE_BUILD", value = nil },
    { key = "STARTUP_TEST_PROFILE", value = nil },
  }, function()
    local policy = startup_policy.resolve(_G)
    assert(policy.release_mode == true, "startup should default to release mode")
    assert(policy.profile_name == "default", "startup should use default profile when unset")
  end)
end

local function _test_startup_policy_accepts_explicit_profile_override()
  with_patches({
    { key = "RELEASE_BUILD", value = nil },
    { key = "STARTUP_TEST_PROFILE", value = "market" },
  }, function()
    local policy = startup_policy.resolve(_G)
    assert(policy.release_mode == true, "startup should still use release mode")
    assert(policy.profile_name == "market", "startup should keep explicit profile override")
  end)
end

local function _test_game_startup_release_fills_synthetic_ai_when_role_roster_empty()
  local created_opts = nil
  with_patches({
    { target = runtime_ports, key = "resolve_roles", value = function() return {} end },
    {
      target = app,
      key = "new",
      value = function(_, opts)
        created_opts = opts
        return {}
      end,
    },
    { target = test_profile_bootstrap, key = "apply", value = function() end },
  }, function()
    local state = game_startup.build_state(function() return nil end, {
      profile_name = "default",
    })
    state.game_factory()
  end)

  assert(type(created_opts) == "table", "startup should still create game options when role roster is empty")
  assert(type(created_opts.role_roster) == "table" and #created_opts.role_roster == 4,
    "startup should synthesize a 4-slot role roster")
  _assert_unique_unit_keys(created_opts.role_roster, 4)
  _assert_synthetic_avatar_keys(created_opts.role_roster, { 1, 2, 3, 4 })
  assert(created_opts.ai[-1] == true and created_opts.ai[-2] == true and created_opts.ai[-3] == true and created_opts.ai[-4] == true,
    "synthetic entries should always be AI")
end

local function _test_game_startup_real_roles_stay_human_by_default()
  local created_opts = nil
  with_patches({
    {
      target = runtime_ports,
      key = "resolve_roles",
      value = function()
        return { _build_role(11), _build_role(22), _build_role(33), _build_role(44) }
      end,
    },
    {
      target = app,
      key = "new",
      value = function(_, opts)
        created_opts = opts
        return {}
      end,
    },
    { target = test_profile_bootstrap, key = "apply", value = function() end },
  }, function()
    local state = game_startup.build_state(function() return nil end, {
      profile_name = "default",
    })
    state.game_factory()
  end)

  assert(type(created_opts) == "table", "startup should create game options for real roles")
  assert(created_opts.ai == nil, "real roles should stay human by default")
end

local function _test_game_startup_mixed_real_and_synthetic_players_keep_slot_avatar_specs()
  local created_opts = nil
  local created_game = nil
  with_patches({
    {
      target = runtime_ports,
      key = "resolve_roles",
      value = function()
        return { _build_role(11) }
      end,
    },
    {
      target = app,
      key = "new",
      value = function(_, opts)
        created_opts = opts
        return {}
      end,
    },
    { target = test_profile_bootstrap, key = "apply", value = function() end },
  }, function()
    local state = game_startup.build_state(function() return nil end, {
      profile_name = "default",
    })
    created_game = state.game_factory()
  end)

  assert(type(created_game) == "table", "mixed startup should still create game")
  assert(type(created_opts) == "table", "mixed startup should still create game options")
  assert(type(created_opts.role_roster) == "table" and #created_opts.role_roster == 4,
    "mixed startup should keep four player slots")
  _assert_synthetic_avatar_keys(created_opts.role_roster, { 2, 3, 4 })
  assert(type(created_game.startup_synthetic_players) == "table" and #created_game.startup_synthetic_players == 3,
    "mixed startup should emit three synthetic specs")
  _assert_startup_synthetic_specs_have_slot_avatars(created_game.startup_synthetic_players, { 2, 3, 4 })
end

return {
  name = "startup_release",
  tests = {
    { name = "startup_policy_defaults_to_release", run = _test_startup_policy_defaults_to_release },
    { name = "startup_policy_accepts_explicit_profile_override", run = _test_startup_policy_accepts_explicit_profile_override },
    {
      name = "game_startup_release_fills_synthetic_ai_when_role_roster_empty",
      run = _test_game_startup_release_fills_synthetic_ai_when_role_roster_empty,
    },
    {
      name = "game_startup_real_roles_stay_human_by_default",
      run = _test_game_startup_real_roles_stay_human_by_default,
    },
    {
      name = "game_startup_mixed_real_and_synthetic_players_keep_slot_avatar_specs",
      run = _test_game_startup_mixed_real_and_synthetic_players_keep_slot_avatar_specs,
    },
  },
}
