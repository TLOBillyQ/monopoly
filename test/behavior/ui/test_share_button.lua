-- 分享按钮（open_share_panel）行为规约：view_command port 把点击转为
-- runtime_ports.emit_event 发全局自定义事件「打开分享任务」（#458 真机实证
-- 通路，编辑器侧同名监听打开分享任务面板），每次点击都发、不锁存；发送失败
-- 只 warn 降级，dispatch 仍报告已处理。share_panel.try_show 三分支返回值也在
-- 此钉住（它仍是托管首点的触发口）：#463 后 foundation 侧是纯契约 port，
-- 下列用例经测试基线装配的真实宿主实现（src/host/share_panel）跑全链路，
-- 只桩 runtime_ports.resolve_role。
local lu = require("luaunit")
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq

local view_command_ports = require("src.ui.ports.view_command")
local share_panel = require("src.foundation.ports.share_panel")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local lock_policy = require("src.ui.input.lock")
local base_nodes = require("src.ui.schema.base")

TestShareButton = {}

function TestShareButton:setUp()
  runtime_ports.reset_for_tests()
end

function TestShareButton:tearDown()
  support.restore_runtime_services()
end

function TestShareButton:test_dispatch_emits_open_share_task_event_and_reports_handled()
  local seen = nil
  runtime_ports.configure({
    emit_event = function(event_name, payload)
      seen = { event_name = event_name, payload = payload }
      return true
    end,
  })
  local ports = view_command_ports.build()
  lu.assertEquals(ports.dispatch({}, { type = "open_share_panel", actor_role_id = 5 }), true,
    "open_share_panel dispatch must report handled")
  lu.assertEquals(seen.event_name, "打开分享任务", "dispatch must emit the share-task open event")
  lu.assertIsTable(seen.payload, "dispatch must emit with a payload table")
end

function TestShareButton:test_every_click_emits_share_task_event_without_latching()
  local calls = 0
  runtime_ports.configure({
    emit_event = function()
      calls = calls + 1
      return true
    end,
  })
  local ports = view_command_ports.build()
  lu.assertEquals(ports.dispatch({}, { type = "open_share_panel", actor_role_id = 1 }), true,
    "first click must report handled")
  lu.assertEquals(ports.dispatch({}, { type = "open_share_panel", actor_role_id = 1 }), true,
    "second click must report handled")
  lu.assertEquals(calls, 2, "every click must emit the event (no latch)")
end

function TestShareButton:test_emit_failure_does_not_break_dispatch_and_next_click_retries()
  local attempts = 0
  runtime_ports.configure({
    emit_event = function()
      attempts = attempts + 1
      return false
    end,
  })
  local ports = view_command_ports.build()
  lu.assertEquals(ports.dispatch({}, { type = "open_share_panel", actor_role_id = 1 }), true,
    "failed emit must not break the view command")
  lu.assertEquals(ports.dispatch({}, { type = "open_share_panel", actor_role_id = 1 }), true,
    "the retry click must also report handled")
  lu.assertEquals(attempts, 2, "failure must not latch: next click retries the emit")
end

function TestShareButton:test_try_show_returns_true_only_when_host_call_completes()
  runtime_ports.configure({
    resolve_role = function()
      return {
        show_map_share_panel = function() end,
      }
    end,
  })
  _assert_eq(share_panel.try_show(1), true, "completed host call must report success")
end

function TestShareButton:test_try_show_returns_false_when_role_cannot_be_resolved()
  runtime_ports.configure({
    resolve_role = function() return nil end,
  })
  _assert_eq(share_panel.try_show(1), false, "unresolved role must report failure")
  _assert_eq(share_panel.try_show(nil), false, "missing actor must report failure")
end

function TestShareButton:test_try_show_returns_false_when_role_lacks_show_map_share_panel()
  runtime_ports.configure({
    resolve_role = function() return {} end,
  })
  _assert_eq(share_panel.try_show(1), false, "role without the method must report failure")
end

function TestShareButton:test_try_show_returns_false_when_host_call_raises()
  runtime_ports.configure({
    resolve_role = function()
      return {
        show_map_share_panel = function()
          error("host exploded")
        end,
      }
    end,
  })
  _assert_eq(share_panel.try_show(1), false, "raising host call must report failure")
end

-- 真机 #458 实证：分享按钮的装饰子节点（环/动效×2/文本）默认吸触摸吞掉点击。
-- 锁定策略施加时（锁定/解锁两态都走 _set_base_auxiliary_touch）必须统一压灭。
local function _apply_lock_and_capture(input_blocked)
  local pressed_all = {}
  local ui = {
    input_blocked = input_blocked,
    market_active = false,
    base_hidden_nodes = {},
    item_slots = {},
    choice_screens = {},
    set_visible = function() end,
    set_touch_enabled = function() end,
    set_touch_enabled_all = function(_, name, enabled)
      pressed_all[#pressed_all + 1] = { name = name, enabled = enabled }
    end,
  }
  lock_policy.apply({ ui = ui }, {})
  return pressed_all
end

local function _assert_decor_pressed_off(input_blocked)
  local pressed = _apply_lock_and_capture(input_blocked)
  local by_name = {}
  for _, entry in ipairs(pressed) do
    by_name[entry.name] = entry.enabled
  end
  for _, name in ipairs(base_nodes.share_decor_nodes) do
    _assert_eq(by_name[name], false,
      "share decor node must be pressed touch-off (input_blocked=" .. tostring(input_blocked)
        .. "): " .. tostring(name))
  end
end

function TestShareButton:test_lock_policy_presses_share_decor_touch_off_when_unlocked()
  _assert_decor_pressed_off(false)
end

function TestShareButton:test_lock_policy_presses_share_decor_touch_off_when_locked()
  _assert_decor_pressed_off(true)
end

return TestShareButton
