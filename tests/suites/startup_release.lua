local support = require("TestSupport")
local with_patches = support.with_patches
local app = support.app
local startup_policy = require("src.app.bootstrap.StartupPolicy")
local game_startup = require("src.app.bootstrap.GameStartup")
local runtime_ports = require("src.core.ports.RuntimePorts")
local test_profile_bootstrap = require("src.app.testing.TestProfileBootstrap")

local function _test_release_prod_forces_default_profile()
  with_patches({
    { key = "RELEASE_BUILD", value = true },
    { key = "RELEASE_ALLOW_TEST_PROFILE", value = nil },
    { key = "STARTUP_TEST_PROFILE", value = "items_move_control" },
  }, function()
    local policy = startup_policy.resolve(_G)
    assert(policy.release_mode == true, "release flag should be enabled")
    assert(policy.release_allow_test_profile == false, "release-prod should disable profile override")
    assert(policy.profile_name == "default", "release should force default profile")
    assert(policy.force_non_p1_ai == false, "release should disable forced non-p1 ai")
    assert(policy.fail_fast_when_roles_empty == true, "release should fail fast on empty role roster")
  end)
end

local function _test_release_qa_accepts_defined_profile()
  with_patches({
    { key = "RELEASE_BUILD", value = true },
    { key = "RELEASE_ALLOW_TEST_PROFILE", value = true },
    { key = "STARTUP_TEST_PROFILE", value = "items_target_disrupt" },
  }, function()
    local policy = startup_policy.resolve(_G)
    assert(policy.release_mode == true, "release mode should stay enabled")
    assert(policy.release_allow_test_profile == true, "release-qa should allow profile override")
    assert(policy.profile_name == "items_target_disrupt", "release-qa should accept defined profile")
  end)
end

local function _test_release_qa_without_profile_falls_back_to_default()
  with_patches({
    { key = "RELEASE_BUILD", value = true },
    { key = "RELEASE_ALLOW_TEST_PROFILE", value = true },
    { key = "STARTUP_TEST_PROFILE", value = nil },
  }, function()
    local policy = startup_policy.resolve(_G)
    assert(policy.release_mode == true, "release mode should stay enabled")
    assert(policy.release_allow_test_profile == true, "release-qa should keep override enabled")
    assert(policy.profile_name == "default", "release-qa without profile should fallback to default")
  end)
end

local function _test_release_qa_unknown_profile_fails_in_profile_resolution()
  with_patches({
    { key = "RELEASE_BUILD", value = true },
    { key = "RELEASE_ALLOW_TEST_PROFILE", value = true },
    { key = "STARTUP_TEST_PROFILE", value = "unknown_profile_for_release_qa" },
  }, function()
    local policy = startup_policy.resolve(_G)
    assert(policy.profile_name == "unknown_profile_for_release_qa", "startup policy should pass through unknown profile name")
    local ok, err = pcall(test_profile_bootstrap.apply, {}, policy.profile_name)
    assert(ok == false, "unknown profile should still fail during profile resolution")
    assert(
      tostring(err):find("unknown test profile", 1, true) ~= nil,
      "unknown profile error should come from profile resolution"
    )
  end)
end

local function _test_startup_policy_dev_accepts_profile_override()
  with_patches({
    { key = "RELEASE_BUILD", value = nil },
    { key = "RELEASE_ALLOW_TEST_PROFILE", value = true },
    { key = "STARTUP_TEST_PROFILE", value = "items_move_control" },
  }, function()
    local policy = startup_policy.resolve(_G)
    assert(policy.release_mode == false, "dev should not mark release mode")
    assert(policy.release_allow_test_profile == true, "dev can ignore release-only override flag")
    assert(policy.profile_name == "items_move_control", "dev should accept startup profile override")
    assert(policy.force_non_p1_ai == true, "dev should keep non-p1 ai policy enabled")
    assert(policy.fail_fast_when_roles_empty == false, "dev should allow empty role fallback")
  end)
end

local function _test_game_startup_release_fails_when_role_roster_empty()
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
      release_mode = true,
      force_non_p1_ai = false,
      fail_fast_when_roles_empty = true,
    })
    local ok, err = pcall(state.game_factory)
    assert(ok == false, "release should fail fast when role roster is empty")
    assert(
      tostring(err):find("release startup failed: role roster is empty", 1, true) ~= nil,
      "release startup failure should report empty role roster"
    )
  end)
  assert(created_opts == nil, "release fail-fast should stop before creating game options")
end

local function _test_game_startup_dev_falls_back_to_debug_players_when_roles_empty()
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
      release_mode = false,
      force_non_p1_ai = true,
      fail_fast_when_roles_empty = false,
    })
    state.game_factory()
  end)
  assert(type(created_opts) == "table", "dev fallback should still build game options")
  assert(type(created_opts.players) == "table" and #created_opts.players == 4, "dev fallback should use debug player roster")
end

return {
  name = "startup_release",
  tests = {
    { name = "release_prod_forces_default_profile", run = _test_release_prod_forces_default_profile },
    { name = "release_qa_accepts_defined_profile", run = _test_release_qa_accepts_defined_profile },
    { name = "release_qa_without_profile_falls_back_to_default", run = _test_release_qa_without_profile_falls_back_to_default },
    {
      name = "release_qa_unknown_profile_fails_in_profile_resolution",
      run = _test_release_qa_unknown_profile_fails_in_profile_resolution,
    },
    { name = "startup_policy_dev_accepts_profile_override", run = _test_startup_policy_dev_accepts_profile_override },
    { name = "game_startup_release_fails_when_role_roster_empty", run = _test_game_startup_release_fails_when_role_roster_empty },
    {
      name = "game_startup_dev_falls_back_to_debug_players_when_roles_empty",
      run = _test_game_startup_dev_falls_back_to_debug_players_when_roles_empty,
    },
  },
}
