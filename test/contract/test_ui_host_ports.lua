-- ui 宿主能力 port 契约（#250）：
-- 1) 未装配时按声明默认值降级（对齐 src/host 无 runtime context 的降级语义）；
-- 2) 装配后透传实现（含 register_custom_event 的双返回值）；
-- 3) 聚合面 host_runtime 的 tips/schedule 走 foundation 真源。
local lu = require("luaunit")
local host_slot = require("src.ui.seams.host_slot")
local host_events = require("src.ui.seams.host_events")
local host_roles = require("src.ui.seams.host_roles")
local host_units = require("src.ui.seams.host_units")
local host_scene_ui = require("src.ui.seams.host_scene_ui")
local host_sfx = require("src.ui.seams.host_sfx")
local ui_host_runtime = require("src.ui.seams.host_runtime")
local host_ports = require("src.ui.seams.host_ports")

-- 单一真源直接消费:契约里的重置面不再逐名重列 5 个 port。
local all_ports = host_ports

TestUiHostPorts = {}

function TestUiHostPorts:tearDown()
  for _, port in ipairs(all_ports) do
    port.reset_for_tests()
  end
end

function TestUiHostPorts:test_slot_forwards_multiple_return_values_when_configured()
  local slot = host_slot.new({ { name = "pair", default = false } })
  slot.configure({
    pair = function(a, b)
      return a, b
    end,
  })
  local first, second = slot.pair("x", "y")
  lu.assertIs(first, "x")
  lu.assertIs(second, "y")
end

function TestUiHostPorts:test_slot_returns_declared_default_when_unconfigured()
  local slot = host_slot.new({ { name = "probe", default = "degraded" } })
  lu.assertIs(slot.probe(), "degraded")
  lu.assertFalse(slot.is_configured())
end

function TestUiHostPorts:test_events_degrade_to_false_and_forward_trigger_handle()
  lu.assertFalse(host_events.register_custom_event("evt", function() end))
  lu.assertFalse(host_events.unregister_custom_event("trigger"))

  host_events.configure({
    register_custom_event = function(name, handler)
      return true, "trigger:" .. name .. ":" .. tostring(type(handler))
    end,
    unregister_custom_event = function()
      return true
    end,
  })
  local ok, trigger = host_events.register_custom_event("evt", function() end)
  lu.assertTrue(ok)
  lu.assertIs(trigger, "trigger:evt:function")
  lu.assertTrue(host_events.unregister_custom_event("trigger"))
end

function TestUiHostPorts:test_roles_degrade_to_empty_roster_and_nil_role()
  local roles = host_roles.resolve_roles()
  lu.assertEquals(roles, {})
  lu.assertNil(host_roles.resolve_role_with(1))

  host_roles.configure({
    resolve_roles = function()
      return { "role_a" }
    end,
    resolve_role_with = function(player_id)
      return { id = player_id }
    end,
  })
  lu.assertEquals(host_roles.resolve_roles(), { "role_a" })
  lu.assertIs(host_roles.resolve_role_with(7).id, 7)
end

function TestUiHostPorts:test_units_and_sfx_degrade_to_nil()
  lu.assertNil(host_units.query_unit("ground"))
  lu.assertNil(host_units.create_unit_group("g", nil, nil))
  lu.assertNil(host_sfx.play_3d_sound(nil, "sound_id"))
end

function TestUiHostPorts:test_scene_ui_reports_no_support_until_configured()
  lu.assertFalse(host_scene_ui.has_scene_ui_support())
  host_scene_ui.configure({
    has_scene_ui_support = function()
      return true
    end,
  })
  lu.assertTrue(host_scene_ui.has_scene_ui_support())
end

function TestUiHostPorts:test_host_ports_single_source_lists_the_five_slots_in_order()
  lu.assertIs(#host_ports, 5)
  lu.assertIs(host_ports[1], host_events)
  lu.assertIs(host_ports[2], host_roles)
  lu.assertIs(host_ports[3], host_units)
  lu.assertIs(host_ports[4], host_sfx)
  lu.assertIs(host_ports[5], host_scene_ui)
end

function TestUiHostPorts:test_slot_exposes_declared_names_in_declaration_order()
  local slot = host_slot.new({
    { name = "alpha", default = false },
    { name = "beta" },
  })
  lu.assertEquals(slot.declared_names(), { "alpha", "beta" })
end

function TestUiHostPorts:test_declared_ports_expose_their_exact_name_lists_in_order()
  -- pin 每个端口声明名单的逐名形态（#293：声明位点被变异成陌生函数名时，
  -- 聚合面/消费点不逐一断言会漏杀——外部依赖这些名字）。
  lu.assertEquals(host_events.declared_names(),
    { "register_custom_event", "unregister_custom_event" })
  lu.assertEquals(host_roles.declared_names(),
    { "resolve_roles", "resolve_role_with" })
  lu.assertEquals(host_units.declared_names(), {
    "query_unit", "query_units", "create_unit_group", "create_unit_with_scale",
    "destroy_unit", "destroy_unit_with_children", "acquire_unit", "release_unit", "prewarm_unit",
  })
end

function TestUiHostPorts:test_declared_ports_keep_their_documented_unconfigured_defaults()
  -- host_events：未装配一律 false；host_roles：名册 → 共享空表、单角色 → nil。
  lu.assertFalse(host_events.register_custom_event("evt", function() end))
  lu.assertFalse(host_events.unregister_custom_event("trigger"))
  lu.assertEquals(host_roles.resolve_roles(), {})
  lu.assertNil(host_roles.resolve_role_with(1))
end

function TestUiHostPorts:test_slot_declared_names_are_not_shared_mutably_across_calls()
  -- 导出的名单被消费方改动不得回污染槽内部状态。
  local names = host_units.declared_names()
  local len = #names
  names[#names + 1] = "intruder"
  lu.assertIs(#host_units.declared_names(), len)
end

function TestUiHostPorts:test_aggregate_surface_exports_exactly_the_declared_names_plus_foundation()
  -- host_runtime 的导出函数名集合 = 各 port 声明名 ∪ {enqueue_tip, schedule}。
  -- 手写 _forward 清单退场后仍逐名等价的回归钉。
  local expected = { enqueue_tip = true, schedule = true }
  for _, port in ipairs(host_ports) do
    for _, name in ipairs(port.declared_names()) do
      expected[name] = true
    end
  end
  local actual = {}
  for key, value in pairs(ui_host_runtime) do
    if type(value) == "function" then
      actual[key] = true
    end
  end
  lu.assertEquals(actual, expected)
end

function TestUiHostPorts:test_aggregate_surface_forwards_ports_and_foundation_sources()
  -- enqueue_tip 走 tips 真源，且为调用时查表：patch tips.enqueue 必须可截获
  local tips = require("src.foundation.tips")
  local seen = nil
  local original_enqueue = tips.enqueue
  tips.enqueue = function(intent)
    seen = intent
    return true
  end
  local ok = ui_host_runtime.enqueue_tip({ text = "hello" })
  tips.enqueue = original_enqueue
  lu.assertTrue(ok)
  lu.assertIs(seen.text, "hello")

  host_units.configure({
    query_unit = function(name)
      return "unit:" .. name
    end,
  })
  lu.assertIs(ui_host_runtime.query_unit("ground"), "unit:ground")

  -- schedule 未配置调度器时同步执行回调（foundation runtime_ports 语义）
  local fired = false
  ui_host_runtime.schedule(nil, function()
    fired = true
  end)
  lu.assertTrue(fired)
end


return TestUiHostPorts
