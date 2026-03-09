local support = require("TestSupport")
local with_patches = support.with_patches
local app = support.app
local startup_policy = require("src.app.bootstrap.startup_policy")
local game_startup = require("src.app.bootstrap.game_startup")
local runtime_ports = require("src.core.ports.runtime_ports")
local test_profile_bootstrap = require("src.app.testing.test_profile_bootstrap")

local function _build_role(role_id)
  return {
    id = role_id,
    get_roleid = function()
      return role_id
    end,
  }
end

local function _test_release_prod_forces_default_profile()
  with_patches({
    { key = "RELEASE_BUILD", value = true },
    { key = "RELEASE_ALLOW_TEST_PROFILE", value = nil },
    { key = "STARTUP_TEST_PROFILE", value = "scenario_market_staging" },
  }, function()
    local policy = startup_policy.resolve(_G)
    assert(policy.release_mode == true, "release flag should be enabled")
    assert(policy.release_allow_test_profile == false, "release-prod should disable profile override")
    assert(policy.profile_name == "default", "release should force default profile")
    assert(policy.ai_mode == "default", "release should keep default ai mode when unset")
    assert(policy.local_human_role_id == nil, "release should not resolve local human role when unset")
    assert(policy.force_non_p1_ai == false, "release should disable forced non-p1 ai")
    assert(policy.fail_fast_when_roles_empty == true, "release should fail fast on empty role roster")
  end)
end

local function _test_release_qa_accepts_defined_profile()
  with_patches({
    { key = "RELEASE_BUILD", value = true },
    { key = "RELEASE_ALLOW_TEST_PROFILE", value = true },
    { key = "STARTUP_TEST_PROFILE", value = "scenario_market_staging" },
  }, function()
    local policy = startup_policy.resolve(_G)
    assert(policy.release_mode == true, "release mode should stay enabled")
    assert(policy.release_allow_test_profile == true, "release-qa should allow profile override")
    assert(policy.profile_name == "scenario_market_staging", "release-qa should accept defined profile")
  end)
end

local function _test_release_qa_accepts_monster_staging_profile_in_startup_chain()
  local created_opts = nil
  local applied_profile = nil
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
    {
      target = test_profile_bootstrap,
      key = "apply",
      value = function(_, profile_name)
        applied_profile = profile_name
      end,
    },
  }, function()
    local state = game_startup.build_state(function() return nil end, {
      profile_name = "scenario_monster_staging",
      release_mode = true,
      force_non_p1_ai = false,
      fail_fast_when_roles_empty = true,
    })
    state.game_factory()
  end)

  assert(type(created_opts) == "table", "release-qa startup should still create game options")
  assert(applied_profile == "scenario_monster_staging", "release-qa startup should pass through monster staging profile")
end

local function _test_release_prod_allows_explicit_ai_mode()
  with_patches({
    { key = "RELEASE_BUILD", value = true },
    { key = "RELEASE_ALLOW_TEST_PROFILE", value = nil },
    { key = "STARTUP_AI_MODE", value = "all_except_local_human" },
    { key = "STARTUP_LOCAL_HUMAN_ROLE_ID", value = "9" },
  }, function()
    local policy = startup_policy.resolve(_G)
    assert(policy.release_mode == true, "release mode should stay enabled")
    assert(policy.profile_name == "default", "release should still force default profile")
    assert(policy.ai_mode == "all_except_local_human", "explicit ai mode should pass through in release")
    assert(policy.local_human_role_id == 9, "explicit local human role should normalize to integer")
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
    { key = "STARTUP_TEST_PROFILE", value = "scenario_market_staging" },
  }, function()
    local policy = startup_policy.resolve(_G)
    assert(policy.release_mode == false, "dev should not mark release mode")
    assert(policy.release_allow_test_profile == true, "dev can ignore release-only override flag")
    assert(policy.profile_name == "scenario_market_staging", "dev should accept startup profile override")
    assert(policy.ai_mode == "default", "dev should default ai mode when unset")
    assert(policy.force_non_p1_ai == true, "dev should keep non-p1 ai policy enabled")
    assert(policy.fail_fast_when_roles_empty == false, "dev should allow empty role fallback")
  end)
end

local function _test_startup_policy_accepts_explicit_ai_mode_in_dev()
  with_patches({
    { key = "RELEASE_BUILD", value = nil },
    { key = "STARTUP_AI_MODE", value = "all_except_local_human" },
    { key = "STARTUP_LOCAL_HUMAN_ROLE_ID", value = "22" },
  }, function()
    local policy = startup_policy.resolve(_G)
    assert(policy.release_mode == false, "dev should stay in dev mode")
    assert(policy.ai_mode == "all_except_local_human", "dev should accept explicit ai mode")
    assert(policy.local_human_role_id == 22, "dev should normalize explicit local human role id")
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

local function _test_game_startup_explicit_ai_mode_keeps_matching_local_role_human()
  local created_opts = nil
  local applied_profile = nil
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
    {
      target = test_profile_bootstrap,
      key = "apply",
      value = function(_, profile_name)
        applied_profile = profile_name
      end,
    },
  }, function()
    local state = game_startup.build_state(function() return nil end, {
      profile_name = "scenario_market_staging",
      ai_mode = "all_except_local_human",
      local_human_role_id = 33,
      release_mode = false,
      force_non_p1_ai = true,
      fail_fast_when_roles_empty = false,
    })
    state.game_factory()
  end)
  assert(type(created_opts) == "table", "explicit ai mode should still create game options")
  assert(type(created_opts.role_roster) == "table" and #created_opts.role_roster == 4, "explicit ai mode should keep role roster")
  assert(created_opts.ai[1] == true and created_opts.ai[2] == true and created_opts.ai[4] == true, "non-local roles should be AI")
  assert(created_opts.ai[3] == nil, "matching local human role should stay human")
  assert(applied_profile == "scenario_market_staging", "profile bootstrap should still compose with explicit ai mode")
end

local function _test_game_startup_explicit_ai_mode_falls_back_to_slot1_when_role_missing()
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
      ai_mode = "all_except_local_human",
      local_human_role_id = 99,
      release_mode = false,
      force_non_p1_ai = false,
      fail_fast_when_roles_empty = false,
    })
    state.game_factory()
  end)
  assert(created_opts.ai[1] == nil, "fallback should keep slot1 human")
  assert(created_opts.ai[2] == true and created_opts.ai[3] == true and created_opts.ai[4] == true, "fallback should move other slots to AI")
end

local function _test_game_startup_explicit_ai_mode_falls_back_to_slot1_for_debug_players()
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
      ai_mode = "all_except_local_human",
      local_human_role_id = 22,
      release_mode = false,
      force_non_p1_ai = false,
      fail_fast_when_roles_empty = false,
    })
    state.game_factory()
  end)
  assert(type(created_opts.players) == "table" and #created_opts.players == 4, "debug fallback should still use 4 debug players")
  assert(created_opts.ai[1] == nil, "debug fallback should keep slot1 human")
  assert(created_opts.ai[2] == true and created_opts.ai[3] == true and created_opts.ai[4] == true, "debug fallback should keep non-slot1 AI")
end

return {
  name = "startup_release",
  tests = {
    { name = "release_prod_forces_default_profile", run = _test_release_prod_forces_default_profile },
    { name = "release_qa_accepts_defined_profile", run = _test_release_qa_accepts_defined_profile },
    {
      name = "release_qa_accepts_monster_staging_profile_in_startup_chain",
      run = _test_release_qa_accepts_monster_staging_profile_in_startup_chain,
    },
    { name = "release_prod_allows_explicit_ai_mode", run = _test_release_prod_allows_explicit_ai_mode },
    { name = "release_qa_without_profile_falls_back_to_default", run = _test_release_qa_without_profile_falls_back_to_default },
    {
      name = "release_qa_unknown_profile_fails_in_profile_resolution",
      run = _test_release_qa_unknown_profile_fails_in_profile_resolution,
    },
    { name = "startup_policy_dev_accepts_profile_override", run = _test_startup_policy_dev_accepts_profile_override },
    { name = "startup_policy_accepts_explicit_ai_mode_in_dev", run = _test_startup_policy_accepts_explicit_ai_mode_in_dev },
    { name = "game_startup_release_fails_when_role_roster_empty", run = _test_game_startup_release_fails_when_role_roster_empty },
    {
      name = "game_startup_dev_falls_back_to_debug_players_when_roles_empty",
      run = _test_game_startup_dev_falls_back_to_debug_players_when_roles_empty,
    },
    {
      name = "game_startup_explicit_ai_mode_keeps_matching_local_role_human",
      run = _test_game_startup_explicit_ai_mode_keeps_matching_local_role_human,
    },
    {
      name = "game_startup_explicit_ai_mode_falls_back_to_slot1_when_role_missing",
      run = _test_game_startup_explicit_ai_mode_falls_back_to_slot1_when_role_missing,
    },
    {
      name = "game_startup_explicit_ai_mode_falls_back_to_slot1_for_debug_players",
      run = _test_game_startup_explicit_ai_mode_falls_back_to_slot1_for_debug_players,
    },
  },
}
