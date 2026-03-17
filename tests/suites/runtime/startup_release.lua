local support = require("support.runtime_support")
local with_patches = support.with_patches
local app = support.app
local startup_policy = require("src.entry.startup_policy")
local game_startup = require("src.entry.start_game")
local runtime_ports = require("src.core.ports.runtime_ports")
local test_profile_bootstrap = require("src.entry.testing.test_profile_bootstrap")
local runtime_refs = require("src.config.content.runtime_refs")
local gameplay_rules = require("src.config.gameplay.gameplay_rules")

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

local function _test_startup_policy_defaults_to_dev()
  with_patches({
    { key = "MONO_BUILD_MODE", value = nil },
    { key = "STARTUP_TEST_PROFILE", value = nil },
  }, function()
    local policy = startup_policy.resolve(_G)
    assert(policy.mode == "dev", "startup should default to dev mode")
    assert(policy.profile_name == "default", "startup should use default profile when unset")
  end)
end

local function _test_startup_policy_accepts_explicit_profile_override()
  with_patches({
    { key = "MONO_BUILD_MODE", value = "release" },
    { key = "STARTUP_TEST_PROFILE", value = "market" },
  }, function()
    local policy = startup_policy.resolve(_G)
    assert(policy.mode == "release", "startup should keep explicit release mode")
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

local function _reload_app_init_with_stubs(startup)
  local capture = {}
  local state = {
    ui = {},
  }
  local logger_stub = {
    configure_host_runtime = function(opts)
      capture.host_runtime = opts
    end,
    info = function(...)
      capture.info = { ... }
    end,
    set_event_collection_enabled_provider = function(fn)
      capture.event_provider = fn
    end,
    set_anim_debug_enabled_provider = function(fn)
      capture.anim_provider = fn
    end,
  }

  with_patches({
    { target = package.loaded, key = "src.entry.init", value = nil },
    { target = package.loaded, key = "src.core.utils.logger", value = logger_stub },
    {
      target = package.loaded,
      key = "src.entry.boot",
      value = {
        install = function()
          capture.runtime_install_called = true
        end,
      },
    },
    {
      target = package.loaded,
      key = "src.entry.start_game",
      value = {
        build_state = function(get_game, opts)
          capture.startup_get_game = get_game
          capture.startup_opts = opts
          return state
        end,
      },
    },
    {
      target = package.loaded,
      key = "src.entry.wire_events",
      value = {
        install = function(installed_state, get_game)
          capture.bridge_state = installed_state
          capture.bridge_get_game = get_game
        end,
      },
    },
    {
      target = package.loaded,
      key = "src.entry.wire_host",
      value = {
        start = function(installed_state, game_ref)
          capture.runtime_start_state = installed_state
          capture.runtime_start_game_ref = game_ref
          return "runtime_started"
        end,
      },
    },
    {
      target = package.loaded,
      key = "src.turn.loop",
      value = {
        set_game = function(installed_state, new_game)
          capture.set_game_state = installed_state
          capture.set_game = new_game
        end,
      },
    },
    {
      target = package.loaded,
      key = "src.entry.start_ui",
      value = {
        install = function(installed_state, current_game_ref, opts)
          capture.ui_state = installed_state
          capture.current_game_ref = current_game_ref
          capture.ui_opts = opts
        end,
      },
    },
    {
      target = package.loaded,
      key = "src.entry.startup_policy",
      value = {
        resolve = function()
          return startup
        end,
      },
    },
    { target = package.loaded, key = "src.core.config.gameplay_rules", value = gameplay_rules },
    {
      key = "GlobalAPI",
      value = {
        show_tips = function(text, duration)
          capture.tip_text = text
          capture.tip_duration = duration
          return "tip_called"
        end,
      },
    },
    {
      key = "SetTimeOut",
      value = function(delay, fn)
        capture.timeout_delay = delay
        capture.timeout_callback = fn
        return "timeout_scheduled"
      end,
    },
  }, function()
    require("src.entry.init")
  end, { skip_runtime_context_refresh = true })

  package.loaded["src.entry.init"] = nil
  capture.state = state
  return capture
end

local function _test_app_init_release_mode_wires_runtime_and_debug_providers()
  gameplay_rules.debug_log_enabled = true
  local capture = _reload_app_init_with_stubs({
    mode = "release",
    profile_name = "market",
  })

  assert(capture.runtime_install_called == true, "app init should install runtime")
  assert(capture.startup_opts.profile_name == "market", "app init should pass resolved startup profile")
  assert(gameplay_rules.debug_log_enabled == false, "release startup should disable gameplay debug logs")
  assert(type(capture.host_runtime.tip_presenter) == "function", "logger tip presenter should be configured")
  assert(type(capture.host_runtime.scheduler) == "function", "logger scheduler should be configured")
  with_patches({
    {
      key = "GlobalAPI",
      value = {
        show_tips = function(text, duration)
          capture.tip_text = text
          capture.tip_duration = duration
          return "tip_called"
        end,
      },
    },
    {
      key = "SetTimeOut",
      value = function(delay, fn)
        capture.timeout_delay = delay
        capture.timeout_callback = fn
        return "timeout_scheduled"
      end,
    },
  }, function()
    assert(capture.host_runtime.tip_presenter("hello", 3) == "tip_called", "tip presenter should forward to GlobalAPI")
    assert(capture.tip_text == "hello" and capture.tip_duration == 3, "tip presenter should forward arguments")
    assert(capture.host_runtime.scheduler(0.25, function() end) == "timeout_scheduled",
      "scheduler should forward to SetTimeOut when available")
  end)
  assert(type(capture.event_provider) == "function", "event debug provider should be installed")
  assert(type(capture.anim_provider) == "function", "anim debug provider should be installed")
  assert(capture.event_provider() == false, "empty debug role state should disable event logging")
  capture.state.ui.debug_log_enabled_by_role = {
    p1 = false,
    p2 = true,
  }
  assert(capture.event_provider() == true, "any enabled role should enable event logging")
  assert(capture.anim_provider() == true, "anim provider should share the same debug source")

  local new_game = { id = 99 }
  capture.state.on_game_replaced(new_game)
  assert(capture.current_game_ref[1] == new_game, "on_game_replaced should update shared game ref")
  assert(capture.set_game_state == capture.state, "on_game_replaced should pass state to gameplay loop")
  assert(capture.set_game == new_game, "on_game_replaced should pass new game to gameplay loop")
  assert(capture.bridge_state == capture.state, "startup bridge should install with created state")
  assert(capture.bridge_get_game() == new_game, "startup bridge getter should read shared game ref")
  assert(capture.ui_opts.start_runtime("ctx_state", { "game_ref" }) == "runtime_started",
    "ui bootstrap should expose runtime start closure")
  assert(capture.runtime_start_state == "ctx_state", "runtime start closure should forward state")
  assert(type(capture.runtime_start_game_ref) == "table", "runtime start closure should forward game ref")
end

local function _test_app_init_non_release_keeps_debug_logs_and_scheduler_fallback()
  gameplay_rules.debug_log_enabled = true
  local capture = {}
  local state = { ui = {} }
  local logger_stub = {
    configure_host_runtime = function(opts)
      capture.host_runtime = opts
    end,
    info = function() end,
    set_event_collection_enabled_provider = function(fn)
      capture.event_provider = fn
    end,
    set_anim_debug_enabled_provider = function(fn)
      capture.anim_provider = fn
    end,
  }

  with_patches({
    { target = package.loaded, key = "src.entry.init", value = nil },
    { target = package.loaded, key = "src.core.utils.logger", value = logger_stub },
    { target = package.loaded, key = "src.entry.boot", value = { install = function() end } },
    { target = package.loaded, key = "src.entry.start_game", value = { build_state = function() return state end } },
    { target = package.loaded, key = "src.entry.wire_events", value = { install = function() end } },
    { target = package.loaded, key = "src.entry.wire_host", value = { start = function() return true end } },
    { target = package.loaded, key = "src.turn.loop", value = { set_game = function() end } },
    { target = package.loaded, key = "src.entry.start_ui", value = { install = function() end } },
    {
      target = package.loaded,
      key = "src.entry.startup_policy",
      value = {
        resolve = function()
          return { mode = "dev", profile_name = "default" }
        end,
      },
    },
    { target = package.loaded, key = "src.core.config.gameplay_rules", value = gameplay_rules },
    { key = "GlobalAPI", value = {} },
    { key = "SetTimeOut", value = nil },
  }, function()
    require("src.entry.init")
  end, { skip_runtime_context_refresh = true })

  package.loaded["src.entry.init"] = nil
  assert(gameplay_rules.debug_log_enabled == true, "non-release startup should keep debug logs enabled")
  assert(capture.host_runtime.tip_presenter("tip", 1) == false, "tip presenter should fall back when GlobalAPI is missing")
  local called = false
  assert(capture.host_runtime.scheduler(0.5, function() called = true end) == true,
    "scheduler should execute callback inline when SetTimeOut is missing")
  assert(called == true, "scheduler fallback should invoke callback")
  assert(capture.event_provider() == false and capture.anim_provider() == false,
    "providers should stay disabled when ui debug flags are absent")
end

return {
  name = "startup_release",
  tests = {
    { name = "startup_policy_defaults_to_dev", run = _test_startup_policy_defaults_to_dev },
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
    {
      name = "app_init_release_mode_wires_runtime_and_debug_providers",
      run = _test_app_init_release_mode_wires_runtime_and_debug_providers,
    },
    {
      name = "app_init_non_release_keeps_debug_logs_and_scheduler_fallback",
      run = _test_app_init_non_release_keeps_debug_logs_and_scheduler_fallback,
    },
  },
}
