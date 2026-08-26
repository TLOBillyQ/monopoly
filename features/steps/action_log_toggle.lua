local dsl = require("packages.acceptance.step_dsl")
local number_utils = require("src.foundation.number")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local event_log_view = require("src.ui.coord.event_log_view")
local presentation_ports = require("src.ui.ports")
local view_command = require("src.ui.input.view_command")
-- 行动日志显隐域绑定（#192 簇 B）：真实 view_command.dispatch 切换逐角色可见性。
local VISIBILITY = { ["隐藏"] = false, ["显示"] = true }
local function _no_op() end
local function _state(w)
  w.action_log_state = w.action_log_state or {
    ui = { debug_visible_by_role = {}, debug_log_enabled_by_role = {}, set_event_log = _no_op, set_event_log_visible = _no_op },
    gameplay_loop_ports = presentation_ports.build(),
  }
  return w.action_log_state
end
local function _role_id(w) return number_utils.to_integer(w.action_log_role_id) or 1 end
local function _visibility(name)
  local visible = VISIBILITY[tostring(name or "")]
  if visible == nil then return nil, "未知行动日志状态: " .. tostring(name) end
  return visible
end
-- 带事件通道的角色,走真实点击路径分支（缺通道的防御分支归行为规约覆盖）。
local function _dispatch_toggle(state, role_id)
  local role = { get_roleid = function() return role_id end, send_ui_custom_event = function() return true end }
  runtime_ports.configure({
    resolve_roles = function() return { role } end,
    resolve_role = function(id) return tostring(id) == tostring(role_id) and role or nil end,
  })
  local ok, err = pcall(view_command.dispatch, state, { type = "toggle_action_log", actor_role_id = role_id })
  runtime_ports.reset_for_tests()
  return ok, err
end
return dsl.steps({
  ["玩家角色ID为1"] = function(w) w.action_log_role_id = 1 end,
  ["该玩家的行动日志当前<初始状态>"] = function(w, a)
    local visible, err = _visibility(a["初始状态"])
    if visible == nil then return nil, err end
    local state, role_id = _state(w), _role_id(w)
    if visible then event_log_view.open(state, role_id) else event_log_view.close(state, role_id) end
  end,
  ["该玩家触发切换行动日志"] = function(w)
    local ok, err = _dispatch_toggle(_state(w), _role_id(w))
    if not ok then return nil, "切换派发失败: " .. tostring(err) end
    return true
  end,
  ["该玩家的行动日志变为<结果状态>"] = function(w, a)
    local expected, err = _visibility(a["结果状态"])
    if expected == nil then return nil, err end
    return dsl.eq(event_log_view.is_open(_state(w), _role_id(w)), expected, "行动日志可见性")
  end,
}, { name = "action_log_toggle" })
