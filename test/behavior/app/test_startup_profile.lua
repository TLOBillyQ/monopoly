local bootstrap = require("test.bootstrap")
bootstrap.install_package_paths()

---@diagnostic disable: different-requires

local lu = require("luaunit")
local support = require("test.support.shared_support")
local with_patches = support.with_patches
local app = require("src.state.game_state")
local startup_roster = require("src.app.roster")
local state_factory = require("src.app.state_factory")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local runtime_refs = require("src.config.content.runtime_refs")
local debug_flags = require("src.config.gameplay.debug_flags")

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
      lu.assertEvalToTrue(entry.unit_key ~= nil, "synthetic entry should provide unit_key")
      lu.assertEvalToTrue(seen[entry.unit_key] == nil, "synthetic unit_key should be unique per match")
      seen[entry.unit_key] = true
    end
  end
  lu.assertEvalToTrue(synthetic_count == expected_count, "unexpected synthetic entry count")
end

local function _assert_synthetic_avatar_keys(entries, expected_slots)
  local expected_by_slot = {}
  for _, slot_index in ipairs(expected_slots or {}) do
    local expected_image_key = runtime_refs.images["AI" .. tostring(slot_index)]
    lu.assertEvalToTrue(expected_image_key ~= nil, "missing runtime ref for AI slot: " .. tostring(slot_index))
    expected_by_slot[slot_index] = expected_image_key
  end

  for slot_index, entry in ipairs(entries or {}) do
    if entry and entry.synthetic == true then
      local expected_image_key = expected_by_slot[slot_index]
      lu.assertEvalToTrue(expected_image_key ~= nil, "unexpected synthetic slot: " .. tostring(slot_index))
      lu.assertEvalToTrue(entry.avatar_image_key == expected_image_key,
        "synthetic slot should use matching AI avatar ref: " .. tostring(slot_index))
      expected_by_slot[slot_index] = nil
    end
  end

  for slot_index, remaining in pairs(expected_by_slot) do
    lu.assertEvalToTrue(remaining == nil, "missing synthetic avatar assertion for slot: " .. tostring(slot_index))
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
      lu.assertEvalToTrue(expected_image_key ~= nil, "unexpected synthetic player id: " .. tostring(spec.player_id))
      lu.assertEvalToTrue(spec.avatar_image_key == expected_image_key,
        "startup synthetic spec should keep slot avatar image key")
      expected_by_player_id[spec.player_id] = nil
    end
  end

  for player_id, remaining in pairs(expected_by_player_id) do
    lu.assertEvalToTrue(remaining == nil, "missing synthetic startup spec for player id: " .. tostring(player_id))
  end
end

local function _build_startup_state()
  return state_factory.build_state({
    get_current_game = function()
      return nil
    end,
    build_game_factory = function(state)
      return startup_roster.build_game_factory(state, {})
    end,
    auto_runner = startup_roster.build_auto_runner(),
  })
end

local function _assert_ai_map_has_no_positive_slot_keys(ai_map, max_slot)
  if ai_map == nil then
    return
  end
  for slot_index = 1, (max_slot or 4) do
    lu.assertEvalToTrue(ai_map[slot_index] == nil, "ai map should not contain slot-index key: " .. tostring(slot_index))
    lu.assertEvalToTrue(ai_map[tostring(slot_index)] == nil,
      "ai map should not contain string slot-index key: " .. tostring(slot_index))
  end
end

-- `logger_overrides` adds/replaces fields on the logger stub (e.g. is_test_mode),
-- letting a case drive the branches app.init takes off the logger surface.
local function _reload_app_init_with_stubs(runner, logger_overrides)
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
    warn = function() end,
    set_ui_sink = function(sink)
      capture.ui_sink = sink
    end,
    configure_game_time = function(api)
      capture.game_time_configured = api
    end,
    reset_time_runtime = function()
      capture.game_time_reset = (capture.game_time_reset or 0) + 1
    end,
    set_anim_debug_enabled_provider = function(fn)
      capture.anim_provider = fn
    end,
  }
  for key, value in pairs(logger_overrides or {}) do
    logger_stub[key] = value
  end

  with_patches({
    { target = package.loaded, key = "src.app", value = nil },
    { target = package.loaded, key = "src.app.init_runtime", value = nil },
    { target = package.loaded, key = "src.foundation.log", value = logger_stub },
    { target = package.loaded, key = "src.foundation.tips", value = tip_queue_stub },
    { target = package.loaded, key = "src.foundation.tip_util", value = nil },
    { target = package.loaded, key = "src.foundation.tip_runtime", value = nil },
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

TestStartupProfile = {}

function TestStartupProfile:test_state_factory_builds_runtime_state_when_package_global_missing()
  with_patches({
    { key = "package", value = nil },
  }, function()
    local state = _build_startup_state()
    lu.assertEvalToTrue(type(state.ui_runtime) == "table", "state_factory should create ui_runtime when package is nil")
    lu.assertEvalToTrue(type(state.board_runtime) == "table", "state_factory should create board_runtime when package is nil")
    lu.assertEvalToTrue(type(state.anim_runtime) == "table", "state_factory should create anim_runtime when package is nil")
    lu.assertEvalToTrue(type(state.turn_runtime) == "table", "state_factory should create turn_runtime when package is nil")
    lu.assertEvalToTrue(type(state.debug_runtime) == "table", "state_factory should create debug_runtime when package is nil")
  end, {
    skip_runtime_context_refresh = true,
  })
end

function TestStartupProfile:test_game_startup_fills_synthetic_ai_when_role_roster_empty()
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
  }, function()
    local state = _build_startup_state()
    state.game_factory()
  end)

  lu.assertEvalToTrue(type(created_opts) == "table", "startup should still create game options when role roster is empty")
  lu.assertEvalToTrue(created_opts.map == require("src.config.content.default_map"),
    "startup should always use the default map")
  lu.assertEvalToTrue(type(created_opts.role_roster) == "table" and #created_opts.role_roster == 4,
    "startup should synthesize a 4-slot role roster")
  _assert_unique_unit_keys(created_opts.role_roster, 4)
  _assert_synthetic_avatar_keys(created_opts.role_roster, { 1, 2, 3, 4 })
  lu.assertEvalToTrue(created_opts.ai[-1] == true and created_opts.ai[-2] == true and created_opts.ai[-3] == true and created_opts.ai[-4] == true,
    "synthetic entries should always be AI")
end

function TestStartupProfile:test_game_startup_real_roles_stay_human_by_default()
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
  }, function()
    local state = _build_startup_state()
    state.game_factory()
  end)

  lu.assertEvalToTrue(type(created_opts) == "table", "startup should create game options for real roles")
  lu.assertEvalToTrue(created_opts.ai == nil, "real roles should stay human by default")
end

function TestStartupProfile:test_game_startup_mixed_real_and_synthetic_players_keep_slot_avatar_specs()
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
  }, function()
    local state = _build_startup_state()
    created_game = state.game_factory()
  end)

  lu.assertEvalToTrue(type(created_game) == "table", "mixed startup should still create game")
  lu.assertEvalToTrue(type(created_opts) == "table", "mixed startup should still create game options")
  lu.assertEvalToTrue(type(created_opts.role_roster) == "table" and #created_opts.role_roster == 4,
    "mixed startup should keep four player slots")
  _assert_synthetic_avatar_keys(created_opts.role_roster, { 2, 3, 4 })
  lu.assertEvalToTrue(type(created_game.startup_synthetic_players) == "table" and #created_game.startup_synthetic_players == 3,
    "mixed startup should emit three synthetic specs")
  _assert_startup_synthetic_specs_have_slot_avatars(created_game.startup_synthetic_players, { 2, 3, 4 })
end

function TestStartupProfile:test_game_startup_mixed_real_and_synthetic_players_ai_map_uses_role_ids_only()
  local created_opts = nil
  with_patches({
    {
      target = runtime_ports,
      key = "resolve_roles",
      value = function()
        return { _build_role(2) }
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
  }, function()
    local state = _build_startup_state()
    state.game_factory()
  end)

  lu.assertEvalToTrue(type(created_opts) == "table", "mixed startup should create game options")
  lu.assertEvalToTrue(type(created_opts.ai) == "table", "mixed startup should create ai map")
  lu.assertEvalToTrue(created_opts.ai[-2] == true and created_opts.ai[-3] == true and created_opts.ai[-4] == true,
    "ai map should mark synthetic role ids")
  _assert_ai_map_has_no_positive_slot_keys(created_opts.ai, 4)
end

function TestStartupProfile:test_app_init_requires_explicit_init_and_runs_once()
  local capture = _reload_app_init_with_stubs(function(capture, app_module)
    lu.assertEvalToTrue(type(app_module) == "table", "bootstrap module should export a table")
    lu.assertEvalToTrue(type(app_module.init) == "function", "bootstrap module should expose init")
    lu.assertEvalToTrue(capture.runtime_install_call_count == nil, "require should not auto-start bootstrap")
    app_module.init()
    lu.assertEvalToTrue(capture.runtime_install_call_count == 1, "first init should install runtime once")
    lu.assertEvalToTrue(capture.startup_state_factory_call_count == 1, "first init should build state once")
    app_module.init()
    lu.assertEvalToTrue(capture.runtime_install_call_count == 1, "second init should not reinstall runtime")
    lu.assertEvalToTrue(capture.startup_state_factory_call_count == 1, "second init should not rebuild state")
  end)

  lu.assertEvalToTrue(capture.runtime_install_called == true, "init should install runtime")
  lu.assertEvalToTrue(capture.startup_opts.profile_name == nil,
    "startup should not pass a profile name")
  lu.assertEvalToTrue(capture.startup_opts.autotest == nil,
    "startup should not pass an autotest selector")
  lu.assertEvalToTrue(type(capture.startup_opts.build_game_factory) == "function",
    "init should hand state_factory a game factory builder")
  lu.assertEvalToTrue(capture.startup_opts.auto_runner ~= nil,
    "init should hand state_factory a built auto runner")
  lu.assertEvalToTrue(type(capture.startup_opts.build_game_factory(capture.state)) == "function",
    "init's game factory builder should produce a callable factory")
end

function TestStartupProfile:test_app_init_ui_warn_sink_routes_only_warn_entries_to_host()
  local capture = _reload_app_init_with_stubs(function(_, app_module)
    app_module.init()
  end)

  local sink = capture.ui_sink
  lu.assertEvalToTrue(type(sink) == "function", "init should register a logger ui warn sink")

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
  }, function()
    -- nil and non-warn entries are dropped before reaching the host presenter
    capture.tip_text = nil
    sink(nil)
    sink({ level = "info", text = "ignored" })
    lu.assertEvalToTrue(capture.tip_text == nil, "non-warn entries must not reach the host")

    -- #522:未显式 opt-in 的 warn(开发者留痕)只进 log.txt,不上屏
    capture.tip_text = nil
    sink({ level = "warn", text = "dev trace" })
    lu.assertEvalToTrue(capture.tip_text == nil, "warn entries without ui=true must not reach the host")

    -- a ui-opted warn entry routes the prefixed text through to the host presenter
    sink({ level = "warn", ui = true, text = "disk full" })
    lu.assertEvalToTrue(capture.tip_text == "[warn] disk full",
      "warn entry should route prefixed text to host, got " .. tostring(capture.tip_text))
  end)

  -- a warn entry with no host table must early-return without error or routing
  with_patches({
    { key = "GlobalAPI", value = false },
  }, function()
    capture.tip_text = nil
    local ok = pcall(sink, { level = "warn", ui = true, text = "no host" })
    lu.assertEvalToTrue(ok, "warn entry without a GlobalAPI table must not error")
    lu.assertEvalToTrue(capture.tip_text == nil, "warn entry without a host table must not route")
  end)
end

function TestStartupProfile:test_app_init_configures_game_time_logger_from_host_clock_api()
  local time_api = {
    get_timestamp = function() return 0 end,
    get_hour = function() return 0 end,
    get_minute = function() return 0 end,
    get_second = function() return 0 end,
  }
  local capture
  with_patches({
    { key = "GameAPI", value = time_api },
  }, function()
    capture = _reload_app_init_with_stubs(function(_, app_module)
      app_module.init()
    end)
  end, { skip_runtime_context_refresh = true })

  lu.assertEvalToTrue(capture.game_time_configured == time_api,
    "a host clock api should configure the game-time logger")
end

function TestStartupProfile:test_app_init_resets_time_runtime_when_host_lacks_clock_api()
  local capture
  with_patches({
    { key = "GameAPI", value = { get_timestamp = function() return 0 end } },
  }, function()
    capture = _reload_app_init_with_stubs(function(_, app_module)
      app_module.init()
    end)
  end, { skip_runtime_context_refresh = true })

  lu.assertEvalToTrue(capture.game_time_configured == nil,
    "an incomplete host clock api should not configure the game-time logger")
  lu.assertEvalToTrue((capture.game_time_reset or 0) >= 1,
    "an incomplete host clock api should reset the time runtime")
end

-- app.init publishes test_mode into the tip runtime. The logger is a host-facing
-- seam, so every way it can answer (absent / true / non-boolean / raising) must
-- land on a definite boolean rather than leaking a stray value or an error.
function TestStartupProfile:test_app_init_publishes_test_mode_when_logger_reports_it_enabled()
  local capture = _reload_app_init_with_stubs(function(_, app_module)
    app_module.init()
  end, { is_test_mode = function() return true end })

  lu.assertEvalToTrue(capture.tip_runtime.test_mode == true,
    "an enabled logger test mode should be published to the tip runtime")
end

function TestStartupProfile:test_app_init_publishes_test_mode_false_when_logger_reports_it_disabled()
  local capture = _reload_app_init_with_stubs(function(_, app_module)
    app_module.init()
  end, { is_test_mode = function() return false end })

  lu.assertEvalToTrue(capture.tip_runtime.test_mode == false,
    "a disabled logger test mode should be published as false")
end

function TestStartupProfile:test_app_init_treats_non_boolean_test_mode_as_disabled()
  local capture = _reload_app_init_with_stubs(function(_, app_module)
    app_module.init()
  end, { is_test_mode = function() return "yes" end })

  lu.assertEvalToTrue(capture.tip_runtime.test_mode == false,
    "a non-boolean test mode should be normalized to false, not forwarded as-is")
end

function TestStartupProfile:test_app_init_treats_raising_test_mode_probe_as_disabled()
  local capture = _reload_app_init_with_stubs(function(_, app_module)
    app_module.init()
  end, { is_test_mode = function() error("test mode probe boom") end })

  lu.assertEvalToTrue(capture.tip_runtime.test_mode == false,
    "a logger that raises while probing test mode should not fail init")
end

function TestStartupProfile:test_app_init_treats_missing_test_mode_probe_as_disabled()
  local capture = _reload_app_init_with_stubs(function(_, app_module)
    app_module.init()
  end, { is_test_mode = "not-a-function" })

  lu.assertEvalToTrue(capture.tip_runtime.test_mode == false,
    "a logger without a callable test-mode probe should report disabled")
end

function TestStartupProfile:test_app_init_wires_runtime_and_debug_providers()
  local capture = _reload_app_init_with_stubs(function(_, app_module)
    app_module.init()
  end)

  lu.assertEvalToTrue(capture.runtime_install_called == true, "app init should install runtime")
  lu.assertEvalToTrue(capture.startup_opts.profile_name == nil,
    "startup should not pass a profile name")
  lu.assertEvalToTrue(capture.startup_opts.autotest == nil,
    "startup should not pass an autotest selector")
  lu.assertEvalToTrue(type(capture.tip_runtime.presenter) == "function", "tip presenter should be configured")
  lu.assertEvalToTrue(type(capture.tip_runtime.scheduler) == "function", "tip scheduler should be configured")
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
    lu.assertEvalToTrue(capture.tip_runtime.presenter("hello", 3) == "tip_called", "tip presenter should forward to GlobalAPI")
    lu.assertEvalToTrue(capture.tip_text == "hello" and capture.tip_duration == 3, "tip presenter should forward arguments")
    -- 私人提示（tip.role_id 非空，如道具槽拒绝）只投给该玩家：GlobalAPI.show_tips
    -- 是全场飘字，把「你的卡现在不能用」广播给所有人既是信息泄露也是噪音。
    local private_tip = {}
    runtime_ports.configure({
      resolve_role = function(role_id)
        private_tip.asked_role_id = role_id
        return {
          show_tips = function(text, duration)
            private_tip.text, private_tip.duration = text, duration
            return true
          end,
        }
      end,
    })
    capture.tip_text = nil
    lu.assertEvalToTrue(capture.tip_runtime.presenter("private", 2.0, { role_id = 7 }) == true,
      "tip with role_id should be delivered per-role")
    lu.assertEvalToTrue(private_tip.asked_role_id == 7, "presenter should resolve the tip's own role")
    lu.assertEvalToTrue(private_tip.text == "private" and private_tip.duration == 2.0,
      "per-role delivery should forward text and duration")
    lu.assertEvalToTrue(capture.tip_text == nil, "per-role tip must not also broadcast")
    -- role 解析不出时回落广播，宿主没有 Role.show_tips 也不能把提示丢掉。
    runtime_ports.configure({ resolve_role = function() return nil end })
    lu.assertEvalToTrue(capture.tip_runtime.presenter("fallback", 1.0, { role_id = 7 }) == "tip_called",
      "unresolvable role should fall back to the broadcast presenter")
    lu.assertEvalToTrue(capture.tip_text == "fallback", "fallback should still show the tip")
    runtime_ports.reset_for_tests()
    lu.assertEvalToTrue(capture.tip_runtime.scheduler(0.25, function() end) == "timeout_scheduled",
      "scheduler should forward to SetTimeOut when available")
  end)
  lu.assertEvalToTrue(type(capture.anim_provider) == "function", "anim debug provider should be installed")
  lu.assertEvalToTrue(capture.anim_provider() == false, "empty anim debug role state should disable animation debug")
  -- Wave 6 decoupling: event_log toggle (debug_log_enabled_by_role) must NOT drive anim debug.
  capture.state.ui.debug_log_enabled_by_role = {
    p1 = false,
    p2 = true,
  }
  lu.assertEvalToTrue(capture.anim_provider() == false,
    "anim provider must be independent from event_log toggle (debug_log_enabled_by_role)")
  -- Anim debug now reads its own per-role table.
  capture.state.ui.anim_debug_enabled_by_role = {
    p1 = false,
    p2 = true,
  }
  lu.assertEvalToTrue(capture.anim_provider() == true,
    "anim provider should read its own anim_debug_enabled_by_role flag")
  capture.state.ui.anim_debug_enabled_by_role = {
    p1 = false,
    p2 = false,
  }
  lu.assertEvalToTrue(capture.anim_provider() == false,
    "anim provider should disable when no role enables anim_debug_enabled_by_role")

  lu.assertEvalToTrue(capture.startup_get_game() == nil, "startup game getter should read nil before replace")
  local new_game = { id = 99 }
  capture.state.on_game_replaced(new_game)
  lu.assertEvalToTrue(capture.current_game_ref[1] == new_game, "on_game_replaced should update shared game ref")
  lu.assertEvalToTrue(capture.set_game_state == capture.state, "on_game_replaced should pass state to gameplay loop")
  lu.assertEvalToTrue(capture.set_game == new_game, "on_game_replaced should pass new game to gameplay loop")
  lu.assertEvalToTrue(capture.bridge_state == capture.state, "startup bridge should install with created state")
  lu.assertEvalToTrue(capture.bridge_get_game() == new_game, "startup bridge getter should read shared game ref")
  lu.assertEvalToTrue(capture.startup_get_game() == new_game, "startup game getter should read the replaced game")
  lu.assertEvalToTrue(capture.ui_opts.start_runtime("ctx_state", { "game_ref" }) == "runtime_started",
    "ui bootstrap should expose runtime start closure")
  lu.assertEvalToTrue(capture.runtime_start_state == "ctx_state", "runtime start closure should forward state")
  lu.assertEvalToTrue(type(capture.runtime_start_game_ref) == "table", "runtime start closure should forward game ref")
end

function TestStartupProfile:test_app_init_keeps_scheduler_fallback()
  local capture = {}
  local state = { ui = {} }
  local tip_queue_stub = {
    configure_runtime = function(opts)
      capture.tip_runtime = opts
    end,
  }
  local logger_stub = {
    info = function() end,
    warn = function() end,
    set_ui_sink = function() end,
    set_anim_debug_enabled_provider = function(fn)
      capture.anim_provider = fn
    end,
  }

  with_patches({
    { target = package.loaded, key = "src.app", value = nil },
    { target = package.loaded, key = "src.app.init_runtime", value = nil },
    { target = package.loaded, key = "src.foundation.log", value = logger_stub },
    { target = package.loaded, key = "src.foundation.tips", value = tip_queue_stub },
    { target = package.loaded, key = "src.foundation.tip_util", value = nil },
    { target = package.loaded, key = "src.foundation.tip_runtime", value = nil },
    { target = package.loaded, key = "src.app.host_install", value = { install = function() end } },
    { target = package.loaded, key = "src.app.state_factory", value = { build_state = function() return state end } },
    { target = require("src.app.event_bridge"), key = "install", value = function() end },
    { target = package.loaded, key = "src.app.gameplay_start", value = { start = function() return true end } },
    { target = package.loaded, key = "src.turn.loop", value = { set_game = function() end } },
    { target = package.loaded, key = "src.app.ui_bootstrap", value = { install = function() end } },
    { target = package.loaded, key = "src.config.gameplay.debug_flags", value = debug_flags },
    { key = "GlobalAPI", value = {} },
    { key = "SetTimeOut", value = nil },
  }, function()
    local app_module = require("src.app")
    app_module.init()
  end, { skip_runtime_context_refresh = true })

  package.loaded["src.app"] = nil
  lu.assertEvalToTrue(capture.tip_runtime.presenter("tip", 1) == false, "tip presenter should fall back when GlobalAPI is missing")
  local called = false
  lu.assertEvalToTrue(capture.tip_runtime.scheduler(0.5, function() called = true end) == true,
    "scheduler should execute callback inline when SetTimeOut is missing")
  lu.assertEvalToTrue(called == true, "scheduler fallback should invoke callback")
  lu.assertEvalToTrue(capture.anim_provider() == false,
    "anim provider should stay disabled when ui debug flags are absent")
end

-- 批3 击杀：_globalapi_missing_warned 去重状态机（L17 初值 / L41 守卫 / L42 置位 /
-- L47 宿主就绪复位）与 L43 日志 tag/文案，一次会话内全部 pin 死。
function TestStartupProfile:test_app_init_tip_presenter_warns_once_until_host_ready()
  local warn_calls = {}
  local capture = _reload_app_init_with_stubs(function(_, app_module)
    app_module.init()
  end, {
    warn = function(...)
      warn_calls[#warn_calls + 1] = { ... }
    end,
  })

  local presenter = capture.tip_runtime.presenter
  with_patches({ { key = "GlobalAPI", value = nil } }, function()
    lu.assertEvalToTrue(presenter("first", 1) == false, "missing GlobalAPI should drop the tip")
    lu.assertEvalToTrue(#warn_calls == 1, "first drop without host should warn once")
    lu.assertEvalToTrue(warn_calls[1][1] == "[app]", "drop warning should carry the app tag")
    lu.assertEvalToTrue(
      warn_calls[1][2] == "GlobalAPI.show_tips not available - tips will be dropped until host is ready",
      "drop warning should carry the host-not-ready notice")
    presenter("second", 1)
    lu.assertEvalToTrue(#warn_calls == 1, "repeat drops before host ready must not warn again")
  end)

  with_patches({
    { key = "GlobalAPI", value = { show_tips = function() return "tip_called" end } },
  }, function()
    lu.assertEvalToTrue(presenter("ready", 1) == "tip_called", "tips should route once the host is ready")
  end)

  with_patches({ { key = "GlobalAPI", value = nil } }, function()
    presenter("again", 1)
    lu.assertEvalToTrue(#warn_calls == 2,
      "drops after a host-ready window must warn again (missing flag should reset)")
  end)
end

-- 批3 击杀：scheduler 在既无 SetTimeOut 又无回调时返回 false（L58），
-- tip_queue 据此判定「未排程→立即释放」。
function TestStartupProfile:test_app_init_scheduler_rejects_work_without_callback()
  local capture = _reload_app_init_with_stubs(function(_, app_module)
    app_module.init()
  end)

  with_patches({ { key = "SetTimeOut", value = nil } }, function()
    lu.assertEvalToTrue(capture.tip_runtime.scheduler(0, nil) == false,
      "scheduler without callback and without host timeout should report unscheduled")
  end)
end

function TestStartupProfile:test_app_module_exposes_init_function()
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
    lu.assertEvalToTrue(type(app_module) == "table", "app module should export a table")
    lu.assertEvalToTrue(type(app_module.init) == "function", "app module should expose init")
    lu.assertEvalToTrue(capture.app_init_call_count == 0, "require should not auto-start app init")
    lu.assertEvalToTrue(app_module.init() == "bootstrap_state",
      "app init should return bootstrap state")
  end, { skip_runtime_context_refresh = true })

  lu.assertEvalToTrue(capture.app_init_call_count == 1, "app init should be callable once")
end

function TestStartupProfile:test_main_lua_calls_app_init()
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
    lu.assertEvalToTrue(chunk() == nil, "main.lua should not return a value")
  end, { skip_runtime_context_refresh = true })

  lu.assertEvalToTrue(capture.app_init_call_count == 1, "main.lua should call app init once")
end

function TestStartupProfile:test_gameplay_start_sets_current_game_before_priming_first_turn()
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
      lu.assertEvalToTrue(current_game_ref[1] == self, "gameplay_start should publish current_game before priming first turn")
    end,
  }

  with_patches({
    {
      target = require("src.turn.loop"),
      key = "new_game",
      value = function(state)
        lu.assertEvalToTrue(state ~= nil, "gameplay_start should pass state to gameplay_loop.new_game")
        return fake_game
      end,
    },
    {
      target = require("src.turn.loop"),
      key = "set_game",
      value = function(_, game)
        lu.assertEvalToTrue(game == fake_game, "gameplay_start should pass created game to gameplay_loop.set_game")
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
      target = require("src.ui.coord.deps"),
      key = "build",
      value = function()
        return {}
      end,
    },
  }, function()
    local state = {
      tick_handle = {},
    }
    local result = gameplay_start.start(state, current_game_ref)
    lu.assertEvalToTrue(result == fake_game, "gameplay_start should return created game")
  end)

  lu.assertEvalToTrue(advanced == true, "gameplay_start should prime first turn when new game is at start phase")
  lu.assertEvalToTrue(current_game_ref[1] == fake_game, "gameplay_start should store current_game_ref after start")
end


return TestStartupProfile
