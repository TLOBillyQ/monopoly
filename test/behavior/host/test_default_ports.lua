---@diagnostic disable: need-check-nil, different-requires, undefined-field

local lu = require("luaunit")
local default_ports = require("src.host.default_ports")

-- 原生 LuaUnit 试点(推翻自研 busted 兼容运行器决策的迁移):describe 嵌套按钩子边界拍平成两个
-- Test* 类(外层无用例子句 → 无钩子类;内层「custom archive access」的
-- before_each/after_each → setUp/tearDown,共享 local original_enums → self
-- 字段),用例数与改写前一一对应(2 + 4 = 6 例)。

TestDefaultPorts = {}

function TestDefaultPorts:test_end_game_routes_to_host_and_leaves_diagnostics()
  -- #609 审查收口:end_game 必须直调宿主 game_end;API 缺失与宿主抛错都要
  -- 留痕并返回 false,不得静默、不得上抛(上抛会沿事件回调跳过后续收尾)。
  local host_calls = 0
  local function _ports_with_game_api(game_api)
    return default_ports.build({ current = function()
      return { env = { GameAPI = game_api } }
    end })
  end

  local ports = _ports_with_game_api({
    game_end = function()
      host_calls = host_calls + 1
    end,
  })
  lu.assertEquals(ports.end_game(), true, "end_game should confirm a successful host call")
  lu.assertEquals(host_calls, 1, "end_game should reach the host exactly once")

  local logger = require("src.foundation.log")
  local original_warn = logger.warn
  local warns = {}
  logger.warn = function(...)
    warns[#warns + 1] = table.concat({ ... }, " ")
  end
  local ok_missing, missing_result = pcall(function()
    return _ports_with_game_api({}).end_game()
  end)
  local ok_raising, raising_result = pcall(function()
    return _ports_with_game_api({
      game_end = function()
        error("host exploded")
      end,
    }).end_game()
  end)
  logger.warn = original_warn

  lu.assertEquals(ok_missing and missing_result == false, true, "missing game_end should report false, not raise")
  lu.assertEquals(ok_raising and raising_result == false, true, "raising host game_end must be contained and report false")
  lu.assertEquals(#warns, 2, "missing and raising host game_end should each leave one warn")
end

function TestDefaultPorts:test_wall_diff_seconds_prefers_game_api_then_falls_back()
  local ctx = {
    env = {
      GameAPI = {
        get_timestamp_diff = function(current, previous)
          return (current - previous) * 2
        end,
      },
    },
  }
  local runtime_ctx = {
    current = function()
      return ctx
    end,
  }
  local ports = default_ports.build(runtime_ctx)

  lu.assertEquals(ports.wall_diff_seconds(9, 7), 4, "wall diff should prefer GameAPI semantics when available")
  ctx.env.GameAPI.get_timestamp_diff = nil
  lu.assertEquals(ports.wall_diff_seconds(9, 7), 2, "wall diff should fall back to arithmetic when GameAPI diff is unavailable")
  lu.assertEquals(ports.wall_diff_seconds("x", 7), 0, "wall diff should return 0 for non-numeric fallback inputs")
end

function TestDefaultPorts:test_cpu_now_seconds_prefers_game_api_then_falls_back()
  local ctx = { env = {} }
  local runtime_ctx = {
    current = function()
      return ctx
    end,
  }
  local ports = default_ports.build(runtime_ctx)

  local now = ports.cpu_now_seconds()
  lu.assertIsNumber(now, "cpu_now should produce a number even without GameAPI")

  ctx.env.GameAPI = { get_timestamp = function() return 12345 end }
  lu.assertEquals(ports.cpu_now_seconds(), 12345, "cpu_now should prefer GameAPI timestamp when available")
end

function TestDefaultPorts:test_wall_now_hms_formats_from_game_api_parts()
  local ctx = {
    env = {
      GameAPI = {
        get_timestamp = function() return 1000 end,
        get_hour = function() return 10 end,
        get_minute = function() return 30 end,
        get_second = function() return 45 end,
      },
    },
  }
  local runtime_ctx = {
    current = function()
      return ctx
    end,
  }
  local ports = default_ports.build(runtime_ctx)

  lu.assertEquals(ports.wall_now_hms(), "10:30:45", "wall_now_hms should format from GameAPI parts")
  ctx.env.GameAPI.get_hour = nil
  lu.assertEquals(ports.wall_now_hms(), "", "missing part should yield empty string")
  ctx.env.GameAPI = nil
  lu.assertEquals(ports.wall_now_hms(), "", "no GameAPI should yield empty string")
end

function TestDefaultPorts:test_rng_next_int_routes_to_the_host_random_int_and_guards_its_inputs()
  local seen = nil
  local function _ports_with_game_api(game_api)
    return default_ports.build({ current = function()
      return { env = { GameAPI = game_api } }
    end })
  end

  local ports = _ports_with_game_api({
    random_int = function(min, max)
      seen = { min = min, max = max }
      return 5
    end,
  })

  lu.assertEquals(ports.rng_next_int(1, 10), 5, "rng_next_int should return the host random value")
  lu.assertEquals(seen.min, 1, "rng_next_int should pass the min bound through")
  lu.assertEquals(seen.max, 10, "rng_next_int should pass the max bound through")

  local ok_missing_min, err_missing_min = pcall(ports.rng_next_int, nil, 10)
  lu.assertFalse(ok_missing_min, "rng_next_int should assert on a missing min bound")
  lu.assertEquals(string.find(tostring(err_missing_min), "rng.next_int requires min/max", 1, true) ~= nil, true,
    "missing-min error should carry the reason; got " .. tostring(err_missing_min))

  local ports_no_api = _ports_with_game_api({})
  local ok_no_api, err_no_api = pcall(ports_no_api.rng_next_int, 1, 10)
  lu.assertFalse(ok_no_api, "rng_next_int should assert when the host lacks random_int")
  lu.assertEquals(string.find(tostring(err_no_api), "missing game api random_int", 1, true) ~= nil, true,
    "missing-api error should carry the reason; got " .. tostring(err_no_api))
end

function TestDefaultPorts:test_schedule_forwards_delay_and_callback_to_lua_api()
  local seen = nil
  local ctx = {
    env = {
      LuaAPI = {
        call_delay_time = function(delay, fn)
          seen = { delay = delay, fn = fn }
        end,
      },
    },
  }
  local ports = default_ports.build({ current = function() return ctx end })

  local called = false
  ports.schedule(nil, function()
    called = true
  end)
  lu.assertEquals(seen.delay, 0, "schedule should default a nil delay to 0")
  lu.assertEquals(called, false, "schedule should not invoke the callback synchronously when LuaAPI is present")

  seen = nil
  ports.schedule(3, function() end)
  lu.assertEquals(seen.delay, 3, "schedule should pass the explicit delay through")
end

function TestDefaultPorts:test_schedule_falls_back_to_sync_call_without_lua_api()
  local ctx = { env = {} }
  local ports = default_ports.build({ current = function() return ctx end })

  local called = false
  ports.schedule(1, function()
    called = true
  end)
  lu.assertEquals(called, true, "schedule should invoke the callback synchronously without LuaAPI")

  local ok, err = pcall(ports.schedule, 1, nil)
  lu.assertEquals(ok, false, "schedule should assert on a missing callback")
  lu.assertEquals(string.find(tostring(err), "schedule requires callback", 1, true) ~= nil, true,
    "missing-callback error should carry the reason; got " .. tostring(err))
end

function TestDefaultPorts:test_resolve_camera_helper_returns_context_helper_or_nil()
  local ports = default_ports.build({ current = function() return nil end })
  lu.assertEquals(ports.resolve_camera_helper(), nil, "no context should yield no camera helper")

  local ctx = { camera_helper = { kind = "cam" } }
  local ports_with_helper = default_ports.build({ current = function() return ctx end })
  lu.assertEquals(ports_with_helper.resolve_camera_helper().kind, "cam", "camera helper should come from the context")
end

function TestDefaultPorts:test_emit_event_delegates_to_the_host_trigger_and_reports_ok()
  local ctx = { env = {} }
  local ports = default_ports.build({ current = function() return ctx end })
  local support = require("test.support.shared_support")

  local received = nil
  local ok_result
  support.with_patches({
    {
      target = _G,
      key = "TriggerCustomEvent",
      value = function(event_name, payload)
        received = { event_name = event_name, payload = payload }
        return true
      end,
    },
  }, function()
    ok_result = ports.emit_event("my.event", { k = 1 })
  end)
  lu.assertEquals(ok_result, true, "emit_event should report success when the host trigger succeeds")
  lu.assertEquals(received.event_name, "my.event", "emit_event should pass the event name through")
  lu.assertEquals(received.payload.k, 1, "emit_event should pass the payload through")

  local raised_result
  support.with_patches({
    {
      target = _G,
      key = "TriggerCustomEvent",
      value = function()
        error("host trigger raised")
      end,
    },
  }, function()
    raised_result = ports.emit_event("my.event", {})
  end)
  lu.assertEquals(raised_result, false, "emit_event should return false when the host trigger raises")

  local missing_result
  support.with_patches({
    {
      target = _G,
      key = "TriggerCustomEvent",
      value = nil,
    },
  }, function()
    missing_result = ports.emit_event("my.event", {})
  end)
  lu.assertEquals(missing_result, false, "emit_event should return false without the host trigger")
end

function TestDefaultPorts:test_resolve_roles_returns_cached_when_populated()
  local ctx = {
    env = {
      GameAPI = {
        get_all_valid_roles = function()
          return { { id = 9 } }
        end,
      },
    },
    roles = { { id = 1 } },
  }
  local ports = default_ports.build({ current = function() return ctx end })

  local roles = ports.resolve_roles()

  lu.assertEquals(#roles, 1, "populated roles should come back as cached")
  lu.assertEquals(roles[1].id, 1, "populated roles should not be replaced by a host query")
end

function TestDefaultPorts:test_resolve_role_returns_nil_without_game_api()
  local ctx = { roles = {} }
  local ports = default_ports.build({ current = function() return ctx end })

  lu.assertEquals(ports.resolve_role(1), nil, "no GameAPI should yield no resolved role (no error)")
  lu.assertEquals(#ports.resolve_roles(), 0, "no GameAPI should yield an empty role list (no error)")
end

function TestDefaultPorts:test_resolve_roles_refreshes_empty_roles_from_game_api()
  local ctx = {
    env = {
      GameAPI = {
        get_all_valid_roles = function()
          return { { id = 1 }, { id = 2 } }
        end,
      },
    },
    roles = {},
  }
  local ports = default_ports.build({ current = function() return ctx end })

  local roles = ports.resolve_roles()

  lu.assertEquals(#roles, 2, "resolve_roles should fall back to the host role query")
  lu.assertEquals(roles[1].id, 1, "resolve_roles should return the queried roles")
  lu.assertEquals(ctx.roles[1].id, 1, "resolve_roles should cache the queried roles back onto the context")
end

function TestDefaultPorts:test_resolve_roles_queries_game_api_when_roles_not_initialized()
  local ctx = {
    env = {
      GameAPI = {
        get_all_valid_roles = function()
          return { { id = 7 } }
        end,
      },
    },
  }
  local ports = default_ports.build({ current = function() return ctx end })

  local roles = ports.resolve_roles()

  lu.assertEquals(#roles, 1, "resolve_roles should query the host when ctx.roles is not a table")
  lu.assertEquals(roles[1].id, 7, "resolve_roles should return the queried role")
end

function TestDefaultPorts:test_is_effect_idle_reports_the_effect_track_state()
  local ctx = { env = {} }
  local ports = default_ports.build({ current = function() return ctx end })
  local support = require("test.support.shared_support")
  local effect_track = require("src.ui.render.support.effect_track")

  local idle_result
  support.with_patches({
    {
      target = effect_track,
      key = "is_idle",
      value = function()
        return false
      end,
    },
  }, function()
    idle_result = ports.is_effect_idle()
  end)
  lu.assertEquals(idle_result, false, "is_effect_idle should delegate to the effect track's idle state")
end

-- effect_track 是 UI 层可选依赖，探测壳的三条异常臂各自定型：
-- require 抛错 / 返回非表 / 表上缺 is_idle 都必须回落「视为空闲」true。
local function _with_effect_track_module(value, fn)
  local support = require("test.support.shared_support")
  support.with_patches({
    { target = package.loaded, key = "src.ui.render.support.effect_track", value = nil },
    { target = package.preload, key = "src.ui.render.support.effect_track", value = value },
  }, fn)
end

function TestDefaultPorts:test_is_effect_idle_falls_back_to_true_when_require_raises()
  local ports = default_ports.build({ current = function() return nil end })
  local result
  _with_effect_track_module(function()
    error("effect track unavailable")
  end, function()
    result = ports.is_effect_idle()
  end)
  lu.assertEquals(result, true, "is_effect_idle should treat an unloadable effect track as idle")
end

function TestDefaultPorts:test_is_effect_idle_falls_back_to_true_when_module_is_not_a_table()
  local ports = default_ports.build({ current = function() return nil end })
  local result
  _with_effect_track_module(function()
    return 42
  end, function()
    result = ports.is_effect_idle()
  end)
  lu.assertEquals(result, true, "is_effect_idle should treat a non-table effect track as idle")
end

function TestDefaultPorts:test_is_effect_idle_falls_back_to_true_when_is_idle_is_missing()
  local ports = default_ports.build({ current = function() return nil end })
  local result
  _with_effect_track_module(function()
    return {}
  end, function()
    result = ports.is_effect_idle()
  end)
  lu.assertEquals(result, true, "is_effect_idle should treat a missing is_idle probe as idle")
end

TestDefaultPortsCustomArchiveAccess = {}

function TestDefaultPortsCustomArchiveAccess:setUp()
  self.original_enums = _G.Enums
  _G.Enums = { ArchiveType = { Int = 4 } }
end

function TestDefaultPortsCustomArchiveAccess:tearDown()
  _G.Enums = self.original_enums
end

local function _ports_with_role(role, game_api)
  local ctx = { env = { GameAPI = game_api }, roles = role and { role } or {} }
  return default_ports.build({ current = function() return ctx end })
end

function TestDefaultPortsCustomArchiveAccess:test_archives_enabled_reflects_game_api_then_defaults_false()
  local ports = _ports_with_role(nil, { is_archives_enabled = function() return true end })
  lu.assertEquals(ports.archives_enabled(), true, "archives_enabled should follow GameAPI when present")

  local ports_off = _ports_with_role(nil, {})
  lu.assertEquals(ports_off.archives_enabled(), false, "archives_enabled should default to false without GameAPI support")

  local ports_no_api = _ports_with_role(nil, nil)
  lu.assertEquals(ports_no_api.archives_enabled(), false, "archives_enabled should be false (not error) when GameAPI is absent")
end

function TestDefaultPortsCustomArchiveAccess:test_get_archive_int_defaults_to_zero_for_non_numeric_archive()
  local role = {
    get_roleid = function() return 9 end,
    get_archive_by_type = function() return "not-a-number" end,
  }
  local ports = _ports_with_role(role, {})

  lu.assertEquals(ports.get_archive_int(9, 1001), 0, "non-numeric archive value should default to 0")
end

function TestDefaultPortsCustomArchiveAccess:test_get_archive_int_reads_int_archive_from_resolved_role()
  local seen = {}
  local role = {
    get_roleid = function() return 9 end,
    get_archive_by_type = function(archive_type, key)
      seen[#seen + 1] = { archive_type = archive_type, key = key }
      return 42
    end,
  }
  local ports = _ports_with_role(role, {})

  lu.assertEquals(ports.get_archive_int(9, 1001), 42, "get_archive_int should return the role's stored value")
  lu.assertEquals(seen[1].archive_type, 4, "get_archive_int should request the Int archive type")
  lu.assertEquals(seen[1].key, 1001, "get_archive_int should pass the archive key through")
  lu.assertEquals(ports.get_archive_int(404, 1001), 0, "get_archive_int should default to 0 for an unresolved role")
end

function TestDefaultPortsCustomArchiveAccess:test_set_archive_int_writes_int_archive_on_resolved_role()
  local written = nil
  local role = {
    get_roleid = function() return 9 end,
    set_archive_by_type = function(archive_type, key, value)
      written = { archive_type = archive_type, key = key, value = value }
      return true
    end,
  }
  local ports = _ports_with_role(role, {})

  lu.assertEquals(ports.set_archive_int(9, 1002, 80000), true, "set_archive_int should report success")
  lu.assertEquals(written.archive_type, 4, "set_archive_int should target the Int archive type")
  lu.assertEquals(written.key, 1002, "set_archive_int should pass the archive key")
  lu.assertEquals(written.value, 80000, "set_archive_int should pass the new value")
  lu.assertEquals(ports.set_archive_int(404, 1002, 1), false, "set_archive_int should fail safely for an unresolved role")
end

-- ═══════════════════════════════════════════════════════════════════════
-- #334 / ADR 0046:mark_role_lose 保留 role.lose() 不换方法,跳过分支必留痕;
-- call_role_die 默认接线到 role_die 宿主适配(ADR 0046)。
-- ═══════════════════════════════════════════════════════════════════════

function TestDefaultPorts:test_mark_role_lose_calls_lose_on_the_role()
  local ctx = { env = {} }
  local runtime_ctx = {
    current = function()
      return ctx
    end,
  }
  local ports = default_ports.build(runtime_ctx)

  local marked = 0
  local role = {
    lose = function()
      marked = marked + 1
    end,
  }
  ports.mark_role_lose(role)
  lu.assertEquals(marked, 1, "mark_role_lose should call role.lose once (#334 keeps the marker method)")
end

function TestDefaultPorts:test_mark_role_lose_warns_when_role_is_nil()
  local ctx = { env = {} }
  local runtime_ctx = {
    current = function()
      return ctx
    end,
  }
  local ports = default_ports.build(runtime_ctx)

  local warns = {}
  local support = require("test.support.shared_support")
  support.with_patches({
    {
      target = require("src.foundation.log"),
      key = "warn",
      value = function(...)
        warns[#warns + 1] = table.concat({ ... }, " ")
      end,
    },
  }, function()
    ports.mark_role_lose(nil)
  end)
  lu.assertEquals(#warns, 1, "nil role must leave exactly one warn (ADR 0046)")
  lu.assertEquals(string.find(warns[1], "role is nil", 1, true) ~= nil, true,
    "nil role warn should carry the skip reason; got " .. tostring(warns[1]))
end

function TestDefaultPorts:test_mark_role_lose_warns_when_role_lacks_lose()
  local ctx = { env = {} }
  local runtime_ctx = {
    current = function()
      return ctx
    end,
  }
  local ports = default_ports.build(runtime_ctx)

  local warns = {}
  local support = require("test.support.shared_support")
  support.with_patches({
    {
      target = require("src.foundation.log"),
      key = "warn",
      value = function(...)
        warns[#warns + 1] = table.concat({ ... }, " ")
      end,
    },
  }, function()
    ports.mark_role_lose({ id = 1 })
  end)
  lu.assertEquals(#warns, 1, "a role without lose must leave exactly one warn (ADR 0046)")
  lu.assertEquals(string.find(warns[1], "lacks lose", 1, true) ~= nil, true,
    "missing-lose warn should carry the skip reason; got " .. tostring(warns[1]))
end

function TestDefaultPorts:test_call_role_die_default_is_wired_to_the_host_adapter()
  local ctx = { env = {} }
  local runtime_ctx = {
    current = function()
      return ctx
    end,
  }
  local ports = default_ports.build(runtime_ctx)

  local role = {
    die = function(_, arg)
      return arg == nil
    end,
  }
  lu.assertEquals(ports.call_role_die(role), true,
    "call_role_die should default to the single-signature host adapter (ADR 0046)")
  lu.assertEquals(ports.call_role_die({}), false,
    "a role without die should fail through the adapter")
end


-- mutate 车道统一返回全部类（#283 多类文件 return 首类假幸存方向）：
-- 正常车道扫 _G 收全部 Test* 类，但 mutate 内建 runner 只跑 return 的表，
-- 只 return 首个类会让其余类的用例在变异车道完全不执行。合并全部类，
-- 每个 test* 方法跑所属类 setUp/tearDown（见 multi_class_return）。
return require("test.support.multi_class_return").merge(
  TestDefaultPorts,
  TestDefaultPortsCustomArchiveAccess
)
