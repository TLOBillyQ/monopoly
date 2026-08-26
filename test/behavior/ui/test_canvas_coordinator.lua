-- canvas_coordinator.lua 直测:覆盖调试画布路径、choice 画布解析、
-- switch_for_role 角色解析分支、switch_by_role_id nil ui 守卫。
local lu = require("luaunit")

local coordinator = require("src.ui.coord.canvas_coordinator")
local ui_events = require("src.ui.coord.ui_events")

TestCanvasCoordinator = {}

local function _spy_sender()
  local calls = {}
  local function send(event_name, payload)
    calls[#calls + 1] = {event_name, payload}
  end
  return send, calls
end

-- spy 记录里事件名的槽位:send_to_all(event, payload) 在 c[1],
-- send_to_role(role, event, payload) 在 c[2]。
local function _has_event(calls, event_name, field)
  for _, c in ipairs(calls) do
    if c[field or 1] == event_name then
      return true
    end
  end
  return false
end

-- resolve_popup_return_canvas: market_active 优先
function TestCanvasCoordinator:test_resolve_popup_returns_market_when_active()
  local ui = { market_active = true }
  lu.assertEquals(coordinator.resolve_popup_return_canvas(ui), coordinator.CANVAS_MARKET)
end

-- resolve_popup_return_canvas: choice_active 次优先
function TestCanvasCoordinator:test_resolve_popup_returns_choice_canvas_for_valid_key()
  local ui = { market_active = false, choice_active = true, active_choice_screen_key = "player" }
  lu.assertEquals(coordinator.resolve_popup_return_canvas(ui), coordinator.CANVAS_PLAYER_CHOICE)
end

-- resolve_popup_return_canvas: choice_active 但 key 无效 → 回落 base
function TestCanvasCoordinator:test_resolve_popup_returns_base_when_choice_key_invalid()
  local ui = { market_active = false, choice_active = true, active_choice_screen_key = "unknown" }
  lu.assertEquals(coordinator.resolve_popup_return_canvas(ui), coordinator.CANVAS_BASE)
end

-- resolve_popup_return_canvas: 无 market 无 choice → base
function TestCanvasCoordinator:test_resolve_popup_returns_base_when_nothing_active()
  local ui = { market_active = false }
  lu.assertEquals(coordinator.resolve_popup_return_canvas(ui), coordinator.CANVAS_BASE)
end

-- resolve_popup_return_canvas: choice_active=false 时 guard 返回 nil
-- 覆盖 _resolve_choice_canvas 中 not ui or not ui.choice_active 的 or 分支
function TestCanvasCoordinator:test_resolve_popup_ignores_choice_when_not_active()
  local ui = { market_active = false, choice_active = false, active_choice_screen_key = "player" }
  lu.assertEquals(coordinator.resolve_popup_return_canvas(ui), coordinator.CANVAS_BASE)
end

-- resolve_canvas_after_popup 委托给 resolve_popup_return_canvas
function TestCanvasCoordinator:test_resolve_canvas_after_popup_delegates()
  local ui = { market_active = true }
  lu.assertEquals(coordinator.resolve_canvas_after_popup(ui), coordinator.CANVAS_MARKET)
end

-- switch_by_role_id: nil ui 提前返回,任何画布事件都不发出
function TestCanvasCoordinator:test_switch_by_role_id_nil_ui_returns_early()
  local send_all, all_calls = _spy_sender()
  local send_role, role_calls = _spy_sender()
  local orig_all = ui_events.send_to_all
  local orig_role = ui_events.send_to_role
  ui_events.send_to_all = send_all
  ui_events.send_to_role = send_role

  coordinator.switch_by_role_id(nil, "target", "role1")

  ui_events.send_to_all = orig_all
  ui_events.send_to_role = orig_role

  lu.assertEquals(#all_calls, 0)
  lu.assertEquals(#role_calls, 0)
end

-- switch: 带 debug_visible_by_role 的 ui 保留调试画布
function TestCanvasCoordinator:test_switch_keeps_debug_canvas_when_debug_visible()
  local send, calls = _spy_sender()
  local orig_send = ui_events.send_to_all
  ui_events.send_to_all = send

  local ui = { debug_visible_by_role = { ["r1"] = true } }
  coordinator.switch(ui, coordinator.CANVAS_BASE)

  ui_events.send_to_all = orig_send

  -- debug 画布不应被隐藏:查 hide 调用中无 CANVAS_DEBUG
  for _, c in ipairs(calls) do
    local event_name = c[1]
    lu.assertNotEquals(event_name, ui_events.hide[coordinator.CANVAS_DEBUG])
  end
end

-- switch: 无 debug 可见时调试画布被隐藏
function TestCanvasCoordinator:test_switch_hides_debug_canvas_when_debug_not_visible()
  local send, calls = _spy_sender()
  local orig_send = ui_events.send_to_all
  ui_events.send_to_all = send

  local ui = {}
  coordinator.switch(ui, coordinator.CANVAS_BASE)

  ui_events.send_to_all = orig_send

  -- debug 画布被隐藏
  lu.assertEvalToTrue(
    _has_event(calls, ui_events.hide[coordinator.CANVAS_DEBUG]),
    "debug canvas should be hidden when not visible"
  )
end

-- switch: debug_visible_by_role 不是 table 时走安全路径,调试画布照常隐藏
function TestCanvasCoordinator:test_switch_with_non_table_debug_by_role()
  local send, calls = _spy_sender()
  local orig_send = ui_events.send_to_all
  ui_events.send_to_all = send

  local ui = { debug_visible_by_role = "not_a_table" }
  coordinator.switch(ui, coordinator.CANVAS_BASE)

  ui_events.send_to_all = orig_send

  lu.assertEvalToTrue(
    _has_event(calls, ui_events.hide[coordinator.CANVAS_DEBUG]),
    "debug canvas should be hidden when debug_visible_by_role is not a table"
  )
end

-- switch: debug_visible_by_role 是 table 但所有值为 false → 调试画布被隐藏
function TestCanvasCoordinator:test_switch_with_debug_table_all_false()
  local send, calls = _spy_sender()
  local orig_send = ui_events.send_to_all
  ui_events.send_to_all = send

  local ui = { debug_visible_by_role = { ["r1"] = false, ["r2"] = false } }
  coordinator.switch(ui, coordinator.CANVAS_BASE)

  ui_events.send_to_all = orig_send

  lu.assertEvalToTrue(
    _has_event(calls, ui_events.hide[coordinator.CANVAS_DEBUG]),
    "debug canvas should be hidden when all entries are false"
  )
end

-- switch_for_role: 带 get_roleid 的角色 + 匹配的 debug 条目 → 保留调试画布
-- 覆盖 _keep_debug_for_role 全部内部判断 (type/~=/table/role_id_utils.read/==/true)
function TestCanvasCoordinator:test_switch_for_role_keeps_debug_for_get_roleid_match()
  local role = {
    get_roleid = function() return "debug_role_1" end,
    send_ui_custom_event = function(_, _) end,
  }
  local send, calls = _spy_sender()
  local orig_send = ui_events.send_to_role
  ui_events.send_to_role = send

  local ui = { debug_visible_by_role = { ["debug_role_1"] = true } }
  coordinator.switch_for_role(ui, coordinator.CANVAS_BASE, role)

  ui_events.send_to_role = orig_send

  -- 调试画布不被隐藏(spy 记录里 c[1] 是 role,c[2] 才是事件名)
  local hide_debug = ui_events.hide[coordinator.CANVAS_DEBUG]
  for _, c in ipairs(calls) do
    lu.assertNotEquals(c[2], hide_debug)
  end
end

-- switch_for_role: 角色无 get_roleid 方法时用 tostring fallback
-- 覆盖 runtime.resolve_role_id 返回 nil → or tostring(role) 路径
-- 以及 _keep_debug_for_role 中 type(debug_by_role)=nil 的 ~= 判断
function TestCanvasCoordinator:test_switch_for_role_falls_back_to_tostring()
  local role = { send_ui_custom_event = function(_, _) end }
  local send, calls = _spy_sender()
  local orig_send = ui_events.send_to_role
  ui_events.send_to_role = send

  -- role 无 get_roleid → resolve_role_id 返回 nil → 用 tostring(role)
  local ui = {}
  coordinator.switch_for_role(ui, coordinator.CANVAS_BASE, role)

  ui_events.send_to_role = orig_send

  -- base canvas show 事件应该被调用
  lu.assertEvalToTrue(#calls >= 2, "should send base and permanent show events")
end

-- switch_for_role: 用 __tostring 元方法使 tostring fallback 匹配 debug 条目
-- 覆盖 L115 的 tostring(role) 和 or→and 突变体
function TestCanvasCoordinator:test_switch_for_role_tostring_fallback_matches_debug_entry()
  local role = { send_ui_custom_event = function(_, _) end }
  -- 设置 __tostring 使 tostring(role) 返回可预测值
  setmetatable(role, { __tostring = function() return "known_role_string" end })

  local send, calls = _spy_sender()
  local orig_send = ui_events.send_to_role
  ui_events.send_to_role = send

  local ui = { debug_visible_by_role = { ["known_role_string"] = true } }
  coordinator.switch_for_role(ui, coordinator.CANVAS_BASE, role)

  ui_events.send_to_role = orig_send

  -- tostring(role) = "known_role_string" 匹配 debug 条目 → 保留调试画布
  local hide_debug = ui_events.hide[coordinator.CANVAS_DEBUG]
  for _, c in ipairs(calls) do
    lu.assertNotEquals(c[2], hide_debug)
  end
end

-- switch_for_role: debug_visible_by_role 不是 table → 不走调试保留,调试画布被隐藏
function TestCanvasCoordinator:test_switch_for_role_non_table_debug_by_role()
  local role = { send_ui_custom_event = function(_, _) end }
  local send, calls = _spy_sender()
  local orig_send = ui_events.send_to_role
  ui_events.send_to_role = send

  local ui = { debug_visible_by_role = 123 }
  coordinator.switch_for_role(ui, coordinator.CANVAS_BASE, role)

  ui_events.send_to_role = orig_send

  -- send_to_role(role, event, payload):spy 记录里 c[1] 是 role,事件名在 c[2]
  lu.assertEvalToTrue(
    _has_event(calls, ui_events.hide[coordinator.CANVAS_DEBUG], 2),
    "debug canvas should be hidden when debug_visible_by_role is not a table"
  )
end

-- switch_by_role_id: runtime_ports.resolve_role 返回 nil 时回落 switch,走 send_to_all 广播
function TestCanvasCoordinator:test_switch_by_role_id_falls_back_when_no_role_resolved()
  local send, calls = _spy_sender()
  local orig_send = ui_events.send_to_all
  ui_events.send_to_all = send

  -- 用一个不存在的 role_id → resolve_role 返回 nil → 走 switch 分支
  local ui = {}
  coordinator.switch_by_role_id(ui, coordinator.CANVAS_BASE, "__nonexistent_role__")

  ui_events.send_to_all = orig_send

  -- 回落 switch 的证据:base 画布 show 事件经 send_to_all 广播发出
  lu.assertEvalToTrue(
    _has_event(calls, ui_events.show[coordinator.CANVAS_BASE]),
    "fallback to switch should broadcast the base canvas show event"
  )
end

return TestCanvasCoordinator
