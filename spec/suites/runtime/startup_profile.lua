local bootstrap = require("spec.bootstrap")
bootstrap.install_package_paths()

---@diagnostic disable: different-requires

local support = require("support.runtime_support")
local with_patches = support.with_patches
local app = support.app
local startup_policy = require("src.app.policy")
local startup_roster = require("src.app.roster")
local state_factory = require("src.app.state_factory")
local runtime_ports = require("src.core.ports.runtime_ports")
local startup_bootstrap = require("src.app.profile_bootstrap")
local startup_profile_source = require("src.app.profile_source")
local runtime_refs = require("src.config.content.runtime_refs")
local debug_flags = require("src.config.gameplay.debug_flags")
local profile_support = require("support.test_profile_support")

local function _reload_module(module_name, reset_module_names)
  for _, name in ipairs(reset_module_names or {}) do
    package.loaded[name] = nil
  end
  return require(module_name)
end

local function _capture_local_function(file_path, local_name)
  local chunk = assert(loadfile(file_path))
  local captured = nil
  local previous_hook, previous_mask, previous_count = debug.gethook()

  local function hook()
    for index = 1, 64 do
      local name, value = debug.getlocal(2, index)
      if not name then
        break
      end
      if name == local_name then
        captured = value
        if previous_hook == nil then
          debug.sethook()
        else
          debug.sethook(previous_hook, previous_mask, previous_count)
        end
        return
      end
    end
  end

  debug.sethook(hook, "l")
  local ok, result = pcall(chunk)
  if previous_hook == nil then
    debug.sethook()
  else
    debug.sethook(previous_hook, previous_mask, previous_count)
  end
  if not ok then
    error(result)
  end
  assert(captured ~= nil, "missing local helper: " .. tostring(local_name))
  return captured, result
end

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

local function _build_startup_state(profile_name)
  return state_factory.build_state({
    profile_name = profile_name,
    get_current_game = function()
      return nil
    end,
    build_game_factory = function(state)
      return startup_roster.build_game_factory(state, {
        profile_name = profile_name,
      })
    end,
    auto_runner = startup_roster.build_auto_runner(),
  })
end

local function _assert_ai_map_has_no_positive_slot_keys(ai_map, max_slot)
  if ai_map == nil then
    return
  end
  for slot_index = 1, (max_slot or 4) do
    assert(ai_map[slot_index] == nil, "ai map should not contain slot-index key: " .. tostring(slot_index))
    assert(ai_map[tostring(slot_index)] == nil,
      "ai map should not contain string slot-index key: " .. tostring(slot_index))
  end
end

local function _test_state_factory_builds_runtime_state_when_package_global_missing()
  with_patches({
    { key = "package", value = nil },
  }, function()
    local state = _build_startup_state("default")
    assert(type(state.ui_runtime) == "table", "state_factory should create ui_runtime when package is nil")
    assert(type(state.board_runtime) == "table", "state_factory should create board_runtime when package is nil")
    assert(type(state.anim_runtime) == "table", "state_factory should create anim_runtime when package is nil")
    assert(type(state.turn_runtime) == "table", "state_factory should create turn_runtime when package is nil")
    assert(type(state.debug_runtime) == "table", "state_factory should create debug_runtime when package is nil")
  end, {
    skip_runtime_context_refresh = true,
  })
end

local function _test_startup_policy_defaults_to_default_profile()
  with_patches({
    { key = "STARTUP_TEST_PROFILE", value = nil },
  }, function()
    local policy = startup_policy.resolve(_G)
    assert(policy.profile_name == "default", "startup should use default profile when unset")
  end)
end

local function _test_startup_policy_accepts_explicit_profile_override()
  with_patches({
    { key = "STARTUP_TEST_PROFILE", value = "market" },
  }, function()
    local policy = startup_policy.resolve(_G)
    assert(policy.profile_name == "market", "startup should keep explicit profile override")
  end)
end

local function _test_startup_policy_accepts_generated_profile_module()
  with_patches({
    { key = "STARTUP_TEST_PROFILE", value = "missile" },
    { key = "STARTUP_PROFILE_SOURCE", value = "generated" },
    { key = "STARTUP_PROFILE_MODULE", value = "Data.StartupProfileGenerated" },
  }, function()
    local policy = startup_policy.resolve(_G)
    assert(policy.profile_name == "missile", "startup should keep generated profile name for logging")
    assert(policy.profile_source == "generated", "startup should keep generated profile source")
    assert(policy.profile_module == "Data.StartupProfileGenerated", "startup should keep generated module path")
  end)
end

local function _test_gameplay_start_sets_current_game_before_priming_first_turn()
  local gameplay_start = require("src.app.gameplay_start")
  local current_game_ref = { nil }
  local advanced = false
  local fake_game = {
    turn = {
      turn_count = 0,
      phase = "start",
      pending_choice = nil,
    },
    advance_turn = function(self)
      advanced = true
      assert(current_game_ref[1] == self, "gameplay_start should publish current_game before priming first turn")
    end,
  }

  with_patches({
    {
      target = require("src.turn.loop"),
      key = "new_game",
      value = function(state)
        assert(state ~= nil, "gameplay_start should pass state to gameplay_loop.new_game")
        return fake_game
      end,
    },
    {
      target = require("src.turn.loop"),
      key = "set_game",
      value = function(_, game)
        assert(game == fake_game, "gameplay_start should pass created game to gameplay_loop.set_game")
      end,
    },
    {
      target = require("src.ui.ports"),
      key = "build",
      value = function()
        return {}
      end,
    },
    {
      target = require("src.ui.ctl.deps"),
      key = "build",
      value = function()
        return {}
      end,
    },
  }, function()
    local state = {
      tick_started = true,
    }
    local result = gameplay_start.start(state, current_game_ref)
    assert(result == fake_game, "gameplay_start should return created game")
  end)

  assert(advanced == true, "gameplay_start should prime first turn when new game is at start phase")
  assert(current_game_ref[1] == fake_game, "gameplay_start should store current_game_ref after start")
end

local function _test_raw_test_profiles_reload_copies_meta_into_profile_table()
  local profiles = _reload_module("src.config.testing.test_profiles", {
    "src.config.testing.test_profiles",
  })
  local bankruptcy = profiles.bankruptcy

  assert(type(bankruptcy) == "table", "raw config should expose named profiles")
  assert(bankruptcy.group == "economy_core", "raw profile should copy meta group")
  assert(bankruptcy.goal == "bankruptcy_rent_resolution", "raw profile should copy meta goal")
  assert(type(bankruptcy.bootstrap) == "table", "raw profile should attach bootstrap payload")
  assert(bankruptcy.bootstrap.players[1].cash == 3000, "raw profile should keep bootstrap content")
end

local function _test_raw_test_profiles_profile_factory_copies_nested_meta_and_bootstrap()
  local profile_factory = _capture_local_function("src/config/testing/test_profiles.lua", "_profile")
  local meta = {
    group = "custom_group",
    nested = {
      marker = "alpha",
    },
    owner_tests = { "runtime.test_profiles" },
  }
  local bootstrap_data = {
    players = {
      [1] = {
        cash = 123,
      },
    },
  }
  local profile = profile_factory(meta, bootstrap_data)

  meta.group = "mutated_group"
  meta.nested.marker = "beta"
  bootstrap_data.players[1].cash = 456

  assert(profile.group == "custom_group", "profile factory should copy top-level meta fields")
  assert(profile.nested.marker == "alpha", "profile factory should copy nested meta tables")
  assert(profile.bootstrap.players[1].cash == 123, "profile factory should copy bootstrap tables")

  local empty_profile = profile_factory({ group = "empty_bootstrap" })
  assert(type(empty_profile.bootstrap) == "table", "profile factory should default bootstrap to a table")
  assert(next(empty_profile.bootstrap) == nil, "profile factory should default bootstrap to an empty table")
  empty_profile.bootstrap.flag = true

  local another_empty_profile = profile_factory({ group = "another_empty_bootstrap" })
  assert(another_empty_profile.bootstrap.flag == nil,
    "profile factory should not share default bootstrap tables")
end

local function _test_test_profile_resolver_returns_fresh_profile_copies()
  local resolver = _reload_module("src.app.testing.test_profile_resolver", {
    "src.config.testing.test_profiles",
    "src.app.testing.test_profiles",
    "src.app.testing.test_profile_resolver",
  })
  local first = resolver.resolve_profile("bankruptcy")
  first.covers[1] = "mutated"
  first.owner_tests[1] = "mutated"
  first.bootstrap.players[1].cash = 1

  local second = resolver.resolve_profile("bankruptcy")

  assert(second.covers[1] == "bankruptcy", "resolver should deep copy covers for each resolve")
  assert(second.owner_tests[1] == "runtime.test_profiles", "resolver should deep copy owner_tests for each resolve")
  assert(second.bootstrap.players[1].cash == 3000, "resolver should deep copy bootstrap for each resolve")
end

local function _test_test_profile_resolver_default_bootstrap_is_empty_and_not_shared()
  local resolver = _reload_module("src.app.testing.test_profile_resolver", {
    "src.config.testing.test_profiles",
    "src.app.testing.test_profiles",
    "src.app.testing.test_profile_resolver",
  })
  local first_bootstrap = resolver.resolve_bootstrap("default")
  first_bootstrap.synthetic = true

  local second_bootstrap = resolver.resolve_bootstrap(nil)

  assert(type(second_bootstrap) == "table", "default bootstrap should always be a table")
  assert(next(second_bootstrap) == nil, "default bootstrap should default to an empty table")
  assert(second_bootstrap.synthetic == nil, "default bootstrap should not share references across resolves")
end

local function _test_game_startup_fills_synthetic_ai_when_role_roster_empty()
  local created_opts = nil
  with_patches({
    { target = runtime_ports, key = "resolve_roles", value = function() return {} end },
    { target = startup_profile_source, key = "resolve_map", value = function() return require("src.config.content.maps.default_map") end },
    { target = startup_profile_source, key = "resolve_bootstrap", value = function() return {} end },
    {
      target = app,
      key = "new",
      value = function(_, opts)
        created_opts = opts
        return {}
      end,
    },
    { target = startup_bootstrap, key = "apply_bootstrap", value = function() end },
  }, function()
    local state = _build_startup_state("default")
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
    { target = startup_profile_source, key = "resolve_map", value = function() return require("src.config.content.maps.default_map") end },
    { target = startup_profile_source, key = "resolve_bootstrap", value = function() return {} end },
    {
      target = app,
      key = "new",
      value = function(_, opts)
        created_opts = opts
        return {}
      end,
    },
    { target = startup_bootstrap, key = "apply_bootstrap", value = function() end },
  }, function()
    local state = _build_startup_state("default")
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
    { target = startup_profile_source, key = "resolve_map", value = function() return require("src.config.content.maps.default_map") end },
    { target = startup_profile_source, key = "resolve_bootstrap", value = function() return {} end },
    {
      target = app,
      key = "new",
      value = function(_, opts)
        created_opts = opts
        return {}
      end,
    },
    { target = startup_bootstrap, key = "apply_bootstrap", value = function() end },
  }, function()
    local state = _build_startup_state("default")
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

local function _test_game_startup_mixed_real_and_synthetic_players_ai_map_uses_role_ids_only()
  local created_opts = nil
  with_patches({
    {
      target = runtime_ports,
      key = "resolve_roles",
      value = function()
        return { _build_role(2) }
      end,
    },
    { target = startup_profile_source, key = "resolve_map", value = function() return require("src.config.content.maps.default_map") end },
    { target = startup_profile_source, key = "resolve_bootstrap", value = function() return {} end },
    {
      target = app,
      key = "new",
      value = function(_, opts)
        created_opts = opts
        return {}
      end,
    },
    { target = startup_bootstrap, key = "apply_bootstrap", value = function() end },
  }, function()
    local state = _build_startup_state("default")
    state.game_factory()
  end)

  assert(type(created_opts) == "table", "mixed startup should create game options")
  assert(type(created_opts.ai) == "table", "mixed startup should create ai map")
  assert(created_opts.ai[-2] == true and created_opts.ai[-3] == true and created_opts.ai[-4] == true,
    "ai map should mark synthetic role ids")
  _assert_ai_map_has_no_positive_slot_keys(created_opts.ai, 4)
end

local function _reload_app_init_with_stubs(startup, runner)
  local capture = {}
  local state = {
    ui = {},
  }
  local tip_queue_stub = {
    configure_runtime = function(opts)
      capture.tip_runtime = opts
    end,
  }
  local logger_stub = {
    info = function(...)
      capture.info = { ... }
    end,
    set_anim_debug_enabled_provider = function(fn)
      capture.anim_provider = fn
    end,
  }

  with_patches({
    { target = package.loaded, key = "src.app", value = nil },
    { target = package.loaded, key = "src.core.utils.logger", value = logger_stub },
    { target = package.loaded, key = "src.core.utils.tip_queue", value = tip_queue_stub },
    {
      target = package.loaded,
      key = "src.app.host_install",
      value = {
        install = function()
          capture.runtime_install_called = true
          capture.runtime_install_call_count = (capture.runtime_install_call_count or 0) + 1
        end,
      },
    },
    {
      target = package.loaded,
      key = "src.app.state_factory",
      value = {
        build_state = function(get_game, opts)
          capture.startup_state_factory_call_count = (capture.startup_state_factory_call_count or 0) + 1
          capture.startup_get_game = get_game
          capture.startup_opts = opts
          return state
        end,
      },
    },
    {
      target = require("src.app.event_bridge"),
      key = "install",
      value = function(installed_state, get_game)
        capture.bridge_state = installed_state
        capture.bridge_get_game = get_game
      end,
    },
    {
      target = package.loaded,
      key = "src.app.gameplay_start",
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
      key = "src.app.ui_bootstrap",
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
      key = "src.app.policy",
      value = {
        resolve = function()
          return startup
        end,
      },
    },
    { target = package.loaded, key = "src.config.gameplay.debug_flags", value = debug_flags },
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
    local app_module = require("src.app")
    if type(runner) == "function" then
      runner(capture, app_module, state)
    end
  end, { skip_runtime_context_refresh = true })

  package.loaded["src.app"] = nil
  capture.state = state
  return capture
end

local function _test_app_init_requires_explicit_init_and_runs_once()
  debug_flags.debug_log_enabled = true
  local capture = _reload_app_init_with_stubs({
    profile_name = "market",
  }, function(capture, app_module)
    assert(type(app_module) == "table", "bootstrap module should export a table")
    assert(type(app_module.init) == "function", "bootstrap module should expose init")
    assert(capture.runtime_install_call_count == nil, "require should not auto-start bootstrap")
    app_module.init()
    assert(capture.runtime_install_call_count == 1, "first init should install runtime once")
    assert(capture.startup_state_factory_call_count == 1, "first init should build state once")
    app_module.init()
    assert(capture.runtime_install_call_count == 1, "second init should not reinstall runtime")
    assert(capture.startup_state_factory_call_count == 1, "second init should not rebuild state")
  end)

  assert(capture.runtime_install_called == true, "init should install runtime")
  assert(capture.startup_opts.profile_name == "market", "init should pass resolved startup profile")
  assert(debug_flags.debug_log_enabled == true, "startup should keep gameplay debug log config unchanged")
end

local function _test_app_init_wires_runtime_and_debug_providers()
  debug_flags.debug_log_enabled = true
  local capture = _reload_app_init_with_stubs({
    profile_name = "market",
  }, function(_, app_module)
    app_module.init()
  end)

  assert(capture.runtime_install_called == true, "app init should install runtime")
  assert(capture.startup_opts.profile_name == "market", "app init should pass resolved startup profile")
  assert(debug_flags.debug_log_enabled == true, "startup should keep gameplay debug log config unchanged")
  assert(type(capture.tip_runtime.presenter) == "function", "tip presenter should be configured")
  assert(type(capture.tip_runtime.scheduler) == "function", "tip scheduler should be configured")
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
    assert(capture.tip_runtime.presenter("hello", 3) == "tip_called", "tip presenter should forward to GlobalAPI")
    assert(capture.tip_text == "hello" and capture.tip_duration == 3, "tip presenter should forward arguments")
    assert(capture.tip_runtime.scheduler(0.25, function() end) == "timeout_scheduled",
      "scheduler should forward to SetTimeOut when available")
  end)
  assert(type(capture.anim_provider) == "function", "anim debug provider should be installed")
  assert(capture.anim_provider() == false, "empty anim debug role state should disable animation debug")
  -- Wave 6 decoupling: event_log toggle (debug_log_enabled_by_role) must NOT drive anim debug.
  capture.state.ui.debug_log_enabled_by_role = {
    p1 = false,
    p2 = true,
  }
  assert(capture.anim_provider() == false,
    "anim provider must be independent from event_log toggle (debug_log_enabled_by_role)")
  -- Anim debug now reads its own per-role table.
  capture.state.ui.anim_debug_enabled_by_role = {
    p1 = false,
    p2 = true,
  }
  assert(capture.anim_provider() == true,
    "anim provider should read its own anim_debug_enabled_by_role flag")
  capture.state.ui.anim_debug_enabled_by_role = {
    p1 = false,
    p2 = false,
  }
  assert(capture.anim_provider() == false,
    "anim provider should disable when no role enables anim_debug_enabled_by_role")

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

local function _test_app_init_keeps_scheduler_fallback()
  debug_flags.debug_log_enabled = true
  local capture = {}
  local state = { ui = {} }
  local tip_queue_stub = {
    configure_runtime = function(opts)
      capture.tip_runtime = opts
    end,
  }
  local logger_stub = {
    info = function() end,
    set_anim_debug_enabled_provider = function(fn)
      capture.anim_provider = fn
    end,
  }

  with_patches({
    { target = package.loaded, key = "src.app", value = nil },
    { target = package.loaded, key = "src.core.utils.logger", value = logger_stub },
    { target = package.loaded, key = "src.core.utils.tip_queue", value = tip_queue_stub },
    { target = package.loaded, key = "src.app.host_install", value = { install = function() end } },
    { target = package.loaded, key = "src.app.state_factory", value = { build_state = function() return state end } },
    { target = require("src.app.event_bridge"), key = "install", value = function() end },
    { target = package.loaded, key = "src.app.gameplay_start", value = { start = function() return true end } },
    { target = package.loaded, key = "src.turn.loop", value = { set_game = function() end } },
    { target = package.loaded, key = "src.app.ui_bootstrap", value = { install = function() end } },
    {
      target = package.loaded,
      key = "src.app.policy",
      value = {
        resolve = function()
          return { profile_name = "default" }
        end,
      },
    },
    { target = package.loaded, key = "src.config.gameplay.debug_flags", value = debug_flags },
    { key = "GlobalAPI", value = {} },
    { key = "SetTimeOut", value = nil },
  }, function()
    local app_module = require("src.app")
    app_module.init()
  end, { skip_runtime_context_refresh = true })

  package.loaded["src.app"] = nil
  assert(debug_flags.debug_log_enabled == true, "startup should keep debug logs enabled")
  assert(capture.tip_runtime.presenter("tip", 1) == false, "tip presenter should fall back when GlobalAPI is missing")
  local called = false
  assert(capture.tip_runtime.scheduler(0.5, function() called = true end) == true,
    "scheduler should execute callback inline when SetTimeOut is missing")
  assert(called == true, "scheduler fallback should invoke callback")
  assert(capture.anim_provider() == false,
    "anim provider should stay disabled when ui debug flags are absent")
end

local function _test_app_module_exposes_init_function()
  local capture = {
    app_init_call_count = 0,
  }

  with_patches({
    {
      target = package.loaded,
      key = "src.app",
      value = {
        init = function()
          capture.app_init_call_count = capture.app_init_call_count + 1
          return "bootstrap_state"
        end,
      },
    },
  }, function()
    local app_module = require("src.app")
    assert(type(app_module) == "table", "app module should export a table")
    assert(type(app_module.init) == "function", "app module should expose init")
    assert(capture.app_init_call_count == 0, "require should not auto-start app init")
    assert(app_module.init() == "bootstrap_state",
      "app init should return bootstrap state")
  end, { skip_runtime_context_refresh = true })

  assert(capture.app_init_call_count == 1, "app init should be callable once")
end

local function _test_main_lua_calls_app_init()
  local capture = {
    app_init_call_count = 0,
  }

  with_patches({
    {
      target = package.loaded,
      key = "src.app",
      value = {
        init = function()
          capture.app_init_call_count = capture.app_init_call_count + 1
          return "app_state"
        end,
      },
    },
  }, function()
    local chunk = assert(loadfile("main.lua"))
    assert(chunk() == nil, "main.lua should not return a value")
  end, { skip_runtime_context_refresh = true })

  assert(capture.app_init_call_count == 1, "main.lua should call app init once")
end

local function _test_upgrade_build_marks_tile_render_called_for_startup_render()
  local game = profile_support.apply_profile("upgrade_build")
  local tile_renderer = require("src.ui.render.tile_renderer")
  local building_effects = require("src.ui.render.building_effects")
  local rendered_tile_ids = {}
  local rendered_building_tile_ids = {}

  profile_support.with_patches({
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
    profile_support.render_profile_startup(game)
  end)

  assert(rendered_tile_ids[1] == 1, "startup render should render configured tile")
  assert(#rendered_tile_ids == 1, "startup render should only render flagged tiles")
  assert(#rendered_building_tile_ids == 0, "level 0 tile should not spawn startup building render")
end

local function _test_strong_card_marks_tile_render_called_for_startup_render()
  local game = profile_support.apply_profile("strong_card")
  local tile_renderer = require("src.ui.render.tile_renderer")
  local building_effects = require("src.ui.render.building_effects")
  local rendered_tile_ids = {}
  local rendered_building_tile_ids = {}

  profile_support.with_patches({
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
    profile_support.render_profile_startup(game)
  end)

  assert(rendered_tile_ids[1] == 12, "startup render should render strong card staging target tile")
  assert(#rendered_tile_ids == 1, "startup render should only render flagged tile")
  assert(rendered_building_tile_ids[1] == 12, "startup render should spawn building for strong card staging target tile")
  assert(#rendered_building_tile_ids == 1, "startup render should only spawn flagged building")
end

local function _test_missile_marks_overlay_render_called_for_startup_render()
  local game = profile_support.apply_profile("missile")
  local overlay_runtime = require("src.ui.render.anim.overlay_runtime")
  local tile_renderer = require("src.ui.render.tile_renderer")
  local building_effects = require("src.ui.render.building_effects")
  local overlay_calls = {}
  local rendered_tile_ids = {}
  local rendered_building_tile_ids = {}

  profile_support.with_patches({
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
    profile_support.render_profile_startup(game)
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
  name = "startup_profile",
  tests = {
    { name = "state_factory_builds_runtime_state_when_package_global_missing", run = _test_state_factory_builds_runtime_state_when_package_global_missing },
    { name = "startup_policy_defaults_to_default_profile", run = _test_startup_policy_defaults_to_default_profile },
    { name = "startup_policy_accepts_explicit_profile_override", run = _test_startup_policy_accepts_explicit_profile_override },
    { name = "startup_policy_accepts_generated_profile_module", run = _test_startup_policy_accepts_generated_profile_module },
    { name = "raw_test_profiles_reload_copies_meta_into_profile_table", run = _test_raw_test_profiles_reload_copies_meta_into_profile_table },
    {
      name = "raw_test_profiles_profile_factory_copies_nested_meta_and_bootstrap",
      run = _test_raw_test_profiles_profile_factory_copies_nested_meta_and_bootstrap,
    },
    { name = "test_profile_resolver_returns_fresh_profile_copies", run = _test_test_profile_resolver_returns_fresh_profile_copies },
    {
      name = "test_profile_resolver_default_bootstrap_is_empty_and_not_shared",
      run = _test_test_profile_resolver_default_bootstrap_is_empty_and_not_shared,
    },
    { name = "game_startup_fills_synthetic_ai_when_role_roster_empty", run = _test_game_startup_fills_synthetic_ai_when_role_roster_empty },
    { name = "game_startup_real_roles_stay_human_by_default", run = _test_game_startup_real_roles_stay_human_by_default },
    { name = "game_startup_mixed_real_and_synthetic_players_keep_slot_avatar_specs", run = _test_game_startup_mixed_real_and_synthetic_players_keep_slot_avatar_specs },
    { name = "game_startup_mixed_real_and_synthetic_players_ai_map_uses_role_ids_only", run = _test_game_startup_mixed_real_and_synthetic_players_ai_map_uses_role_ids_only },
    { name = "app_init_requires_explicit_init_and_runs_once", run = _test_app_init_requires_explicit_init_and_runs_once },
    { name = "app_init_wires_runtime_and_debug_providers", run = _test_app_init_wires_runtime_and_debug_providers },
    { name = "app_init_keeps_scheduler_fallback", run = _test_app_init_keeps_scheduler_fallback },
    {
      name = "app_module_exposes_init_function",
      run = _test_app_module_exposes_init_function,
    },
    { name = "main_lua_calls_app_init", run = _test_main_lua_calls_app_init },
    {
      name = "gameplay_start_sets_current_game_before_priming_first_turn",
      run = _test_gameplay_start_sets_current_game_before_priming_first_turn,
    },
    { name = "upgrade_build_marks_tile_render_called_for_startup_render", run = _test_upgrade_build_marks_tile_render_called_for_startup_render },
    { name = "strong_card_marks_tile_render_called_for_startup_render", run = _test_strong_card_marks_tile_render_called_for_startup_render },
    { name = "missile_marks_overlay_render_called_for_startup_render", run = _test_missile_marks_overlay_render_called_for_startup_render },
  },
}
