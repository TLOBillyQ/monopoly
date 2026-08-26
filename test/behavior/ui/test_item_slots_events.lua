-- item_slots_events 事件路由规约(#262 幸存闭合;#459 外框设施退役)。
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches
local runtime = require("src.ui.render.support.runtime_ui")
local ui_events = require("src.ui.coord.ui_events")
local events = require("src.ui.coord.item_slots_events")

TestItemSlotsEvents = {}

function TestItemSlotsEvents:test_emit_global_reset_animation_routes_to_the_client_role_when_one_is_set()
  -- kills _emit_ui_event 的 runtime.get_client_role() 调用 -> nil
  -- (变异体恒走 send_to_all)。
  local to_role = {}
  local to_all = {}
  local role = { get_roleid = function() return 1 end }

  _with_patches({
    { target = runtime, key = "get_client_role", value = function()
      return role
    end },
    { target = ui_events, key = "send_to_role", value = function(r, event_name)
      to_role[#to_role + 1] = { role = r, event_name = event_name }
    end },
    { target = ui_events, key = "send_to_all", value = function(event_name)
      to_all[#to_all + 1] = event_name
    end },
  }, function()
    events.emit_global_reset_animation()
  end)

  _assert_eq(#to_role, 1, "event should route to the client role")
  _assert_eq(to_role[1].role, role, "event should carry the client role")
  _assert_eq(to_role[1].event_name, "重置高亮", "event name should be the reset animation")
  _assert_eq(#to_all, 0, "event must not broadcast when a client role is set")
end


return TestItemSlotsEvents
