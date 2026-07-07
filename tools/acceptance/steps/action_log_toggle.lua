local number_utils = require("src.foundation.number")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local event_log_view = require("src.ui.coord.event_log_view")
local presentation_ports = require("src.ui.ports")
local view_command = require("src.ui.input.view_command")

local action_log_toggle_steps = {}

-- 行动日志显隐的中文状态名映射到布尔可见性。
local VISIBILITY_STATES = {
  ["隐藏"] = false,
  ["显示"] = true,
}

local function _no_op() end

-- 最小 UI 状态：只承载 toggle_action_log 命令读写的逐角色可见性表与日志可见回调。
local function _ensure_state(world)
  if world.action_log_state then
    return world.action_log_state
  end
  local state = {
    ui = {
      debug_visible_by_role = {},
      debug_log_enabled_by_role = {},
      set_event_log = _no_op,
      set_event_log_visible = _no_op,
    },
    gameplay_loop_ports = presentation_ports.build(),
  }
  world.action_log_state = state
  return state
end

local function _role_id(world)
  return number_utils.to_integer(world.action_log_role_id) or 1
end

-- 带事件通道的角色，对应真实点击路径（玩家始终有 send_ui_custom_event），
-- 让切换走正常分支而非缺通道的防御告警分支（后者归行为规约覆盖）。
local function _make_role(role_id)
  return {
    get_roleid = function()
      return role_id
    end,
    send_ui_custom_event = function()
      return true
    end,
  }
end

local function _resolve_visibility(name)
  local visible = VISIBILITY_STATES[tostring(name or "")]
  if visible == nil then
    return nil, "unknown action log visibility: " .. tostring(name)
  end
  return visible
end

local function _set_initial_visibility(state, role_id, visible)
  if visible then
    event_log_view.open(state, role_id)
  else
    event_log_view.close(state, role_id)
  end
end

-- 配置 runtime 角色解析后派发切换命令，随后复位到验收基线，避免污染同套件其他场景。
local function _dispatch_toggle(state, role_id)
  local role = _make_role(role_id)
  runtime_ports.configure({
    resolve_roles = function()
      return { role }
    end,
    resolve_role = function(id)
      if tostring(id) == tostring(role_id) then
        return role
      end
      return nil
    end,
  })
  local ok, err = pcall(view_command.dispatch, state, {
    type = "toggle_action_log",
    actor_role_id = role_id,
  })
  runtime_ports.reset_for_tests()
  return ok, err
end

function action_log_toggle_steps.handlers()
  return {
    ["玩家角色ID为1"] = function(world)
      world.action_log_role_id = 1
      return true
    end,

    ["该玩家的行动日志当前<初始状态>"] = function(world, example)
      local visible, err = _resolve_visibility(example["初始状态"])
      if visible == nil then
        return nil, err
      end
      _set_initial_visibility(_ensure_state(world), _role_id(world), visible)
      return true
    end,

    ["该玩家触发切换行动日志"] = function(world)
      local ok, err = _dispatch_toggle(_ensure_state(world), _role_id(world))
      if not ok then
        return nil, "toggle dispatch failed: " .. tostring(err)
      end
      return true
    end,

    ["该玩家的行动日志变为<结果状态>"] = function(world, example)
      local expected, err = _resolve_visibility(example["结果状态"])
      if expected == nil then
        return nil, err
      end
      local actual = event_log_view.is_open(_ensure_state(world), _role_id(world))
      if actual ~= expected then
        return nil, "行动日志可见性期望 " .. tostring(expected) .. "，实际 " .. tostring(actual)
      end
      return true
    end,
  }
end

return action_log_toggle_steps
