-- src/ui/ports/view_command.lua 的 dispatch 行为规约。首跑变异的幸存集中在
-- 两类：panel action 转发从未被端到端调用（skin_panel / skin_gallery 的
-- handler 构造换成 nil、require 换成 nil 都活着）,以及 dispatch 的返回值
-- 契约没人断言（handled=true / 未认领=false 的 true/false 常量突变全活）。
local lu = require("luaunit")
local support = require("test.support.shared_support")
local _with_patches = support.with_patches

local view_command_ports = require("src.ui.ports.view_command")
local skin_panel = require("src.ui.screens.skin_panel")
local item_atlas = require("src.ui.screens.item_atlas")
local skin_gallery = require("src.ui.screens.skin_panel.skin_gallery")
local popup_presenter = require("src.ui.coord.popup_presenter")
local command_policy = require("src.ui.input.command_policy")
local actor_context = require("src.ui.coord.actor_context")
local ui_event_state = require("src.ui.coord.event_state")
local event_log_view = require("src.ui.coord.event_log_view")
local canvas = require("src.ui.coord.canvas_coordinator")
local runtime_port = require("src.ui.render.support.runtime_ui")
local logger = require("src.foundation.log")

local function _dispatch_panel_action(module, intent_type)
  local seen = nil
  local handled = nil
  local state = {}
  _with_patches({
    { target = module, key = "handle_action", value = function(s, action, role_id)
      seen = { state = s, action = action, role_id = role_id }
    end },
  }, function()
    local ports = view_command_ports.build()
    handled = ports.dispatch(state, { type = intent_type, action = "equip", actor_role_id = 3 })
  end)
  lu.assertEvalToTrue(seen ~= nil, intent_type .. " must reach the panel handle_action")
  lu.assertEquals(seen.state, state, intent_type .. " must forward the state handle")
  lu.assertEquals(seen.action, "equip", intent_type .. " must forward intent.action")
  lu.assertEquals(seen.role_id, 3, intent_type .. " must forward intent.actor_role_id")
  return handled
end

TestViewCommandPorts = {}

TestViewCommandPorts["test_skin_panel_action 抵达 skin_panel 并报告已处理"] = function(self)
  lu.assertEquals(_dispatch_panel_action(skin_panel, "skin_panel_action"), true,
    "skin_panel_action dispatch must report handled")
end

TestViewCommandPorts["test_item_atlas_action 抵达 item_atlas 并报告已处理"] = function(self)
  lu.assertEquals(_dispatch_panel_action(item_atlas, "item_atlas_action"), true,
    "item_atlas_action dispatch must report handled")
end

TestViewCommandPorts["test_skin_gallery_action 抵达 skin_gallery 并报告已处理"] = function(self)
  lu.assertEquals(_dispatch_panel_action(skin_gallery, "skin_gallery_action"), true,
    "skin_gallery_action dispatch must report handled")
end

TestViewCommandPorts["test_open_skin_panel / open_gallery_panel 打开画廊入口并报告已处理"] = function(self)
  local opened_skin = nil
  local opened_gallery = nil
  local state = {}
  _with_patches({
    { target = skin_gallery, key = "open_skin", value = function(_, role_id) opened_skin = role_id end },
    { target = skin_gallery, key = "open_gallery", value = function(_, role_id) opened_gallery = role_id end },
  }, function()
    local ports = view_command_ports.build()
    lu.assertEquals(ports.dispatch(state, { type = "open_skin_panel", actor_role_id = 2 }), true,
      "open_skin_panel dispatch must report handled")
    lu.assertEquals(ports.dispatch(state, { type = "open_gallery_panel", actor_role_id = 6 }), true,
      "open_gallery_panel dispatch must report handled")
  end)
  lu.assertEquals(opened_skin, 2, "open_skin_panel must forward the acting role to open_skin")
  lu.assertEquals(opened_gallery, 6, "open_gallery_panel must forward the acting role to open_gallery")
end

TestViewCommandPorts["test_popup_confirm 按操作者关闭弹窗并报告已处理"] = function(self)
  local dismissed = nil
  _with_patches({
    { target = popup_presenter, key = "dismiss_popup", value = function(_, actor_role_id)
      dismissed = actor_role_id
    end },
  }, function()
    local ports = view_command_ports.build()
    lu.assertEquals(ports.dispatch({}, { type = "popup_confirm", actor_role_id = 4 }), true,
      "popup_confirm dispatch must report handled")
  end)
  lu.assertEquals(dismissed, 4, "popup_confirm must forward the acting role to dismiss_popup")
end

TestViewCommandPorts["test_没有 port_handler 的指令不被认领,返回 false"] = function(self)
  local ports = view_command_ports.build()
  lu.assertEquals(ports.dispatch({}, { type = "choice_select" }), false,
    "game-handled commands must not be claimed by the view-command port")
  lu.assertEquals(ports.dispatch({}, { type = "not_a_real_command_xyz" }), false,
    "unknown commands must not be claimed by the view-command port")
end

TestViewCommandPorts["test_policy 解析出未实现的 handler key 时不谎报已处理"] = function(self)
  _with_patches({
    { target = command_policy, key = "port_handler", value = function() return "not_a_port_handler" end },
  }, function()
    local ports = view_command_ports.build()
    lu.assertEquals(ports.dispatch({}, { type = "whatever" }), false,
      "a handler key the port does not implement must return false, not handled")
  end)
end

TestViewCommandPorts["test_角色带事件通道时开启日志不产生告警"] = function(self)
  local warnings = {}
  local visible = nil
  local switched = nil
  local role = { send_ui_custom_event = function() end }
  local state = { ui = {} }

  _with_patches({
    { target = actor_context, key = "resolve_role_by_id", value = function() return role end },
    { target = ui_event_state, key = "resolve_event_log_enabled", value = function() return false end },
    { target = event_log_view, key = "set_event_log_visible_for_role", value = function(_, r, enabled)
      visible = { role = r, enabled = enabled }
    end },
    { target = canvas, key = "switch_for_role", value = function(_, canvas_key, r)
      switched = { canvas_key = canvas_key, role = r }
    end },
    { target = runtime_port, key = "set_client_role", value = function() end },
    { target = logger, key = "warn", value = function(...)
      warnings[#warnings + 1] = table.concat({ ... }, " ")
    end },
  }, function()
    local ports = view_command_ports.build()
    lu.assertEquals(ports.dispatch(state, { type = "toggle_action_log", actor_role_id = 9 }), true,
      "toggle_action_log dispatch must report handled")
  end)

  lu.assertEquals(#warnings, 0,
    "a role exposing send_ui_custom_event must not trigger the missing-channel warn; got: "
      .. table.concat(warnings, " | "))
  lu.assertEvalToTrue(visible ~= nil and visible.enabled == true, "the toggle must enable the role event log")
  lu.assertEvalToTrue(switched ~= nil, "enabling must switch the debug canvas for the role")
  lu.assertEquals(switched.canvas_key, canvas.CANVAS_DEBUG, "the switched canvas must be the debug canvas")
end


return TestViewCommandPorts
