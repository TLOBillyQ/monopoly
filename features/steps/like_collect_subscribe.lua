local dsl = require("packages.acceptance.step_dsl")
local with_patches = require("test.support.shared_support").with_patches
local like_collect_subscribe = require("src.host.like_collect_subscribe")

-- #458 点赞/收藏/订阅事件链路验收步骤：驱动真实模块，桩宿主全局捕获调用，
-- 断言全部落在可观测面；步骤内不复刻被测逻辑。
-- 事件名以编辑器配置为真源，这里重复字面量是有意的——src 侧漂移时验收即红。
local LIKE_EVENT = "evt_click_like"
local COLLECT_EVENT = "evt_add_collection"
local SUBSCRIBE_CLICK_EVENT = "evt_not_subscribe"

local function _ensure_state(world)
  if world.lcs then
    return world.lcs
  end
  local state = {
    registrations = {},
    unit_sends = {},
    panel_calls = {},
    tips_calls = {},
    scheduled = {},
    warnings = {},
    fail_host = false,
  }
  state.role = {
    show_like_panel = function()
      state.panel_calls[#state.panel_calls + 1] = true
    end,
    get_ctrl_unit = function()
      return "unit_test"
    end,
    is_subscribed_map_author = function()
      return false
    end,
  }
  world.lcs = state
  return state
end

local function _patches_for(state)
  return {
    {
      key = "EVENT",
      value = { UI_CUSTOM_EVENT = "UI_CUSTOM_EVENT" },
    },
    {
      key = "RegisterTriggerEvent",
      value = function(args, callback)
        state.registrations[#state.registrations + 1] = { args = args, callback = callback }
      end,
    },
    {
      key = "LuaAPI",
      value = {
        unit_send_custom_event = function(unit, event_name, payload)
          if state.fail_host then
            error("unit send boom")
          end
          state.unit_sends[#state.unit_sends + 1] = {
            unit = unit,
            event_name = event_name,
            payload = payload,
          }
        end,
      },
    },
    {
      key = "GameAPI",
      value = {
        get_all_valid_roles = function()
          return { state.role }
        end,
      },
    },
    {
      key = "GlobalAPI",
      value = {
        show_tips = function(text, duration)
          if state.fail_host then
            error("tips boom")
          end
          state.tips_calls[#state.tips_calls + 1] = { text = text, duration = duration }
        end,
      },
    },
    {
      key = "SetTimeOut",
      value = function(delay, callback)
        state.scheduled[#state.scheduled + 1] = { delay = delay, callback = callback }
        return true
      end,
    },
    {
      target = require("src.foundation.log"),
      key = "warn",
      value = function(...)
        state.warnings[#state.warnings + 1] = table.concat({ ... }, " ")
      end,
    },
  }
end

local function _find_callback(state, event_name)
  for _, reg in ipairs(state.registrations) do
    if reg.args[2] == event_name then
      return reg.callback
    end
  end
  return nil
end

local function _run_callback(world, event_name)
  local state = _ensure_state(world)
  return with_patches(_patches_for(state), function()
    local callback = _find_callback(state, event_name)
    if type(callback) ~= "function" then
      return nil, "未注册事件: " .. tostring(event_name)
    end
    callback(nil, nil, { role = state.role })
    return true
  end)
end

return dsl.steps({
  ["点赞收藏订阅事件链路已初始化"] = function(world)
    local state = _ensure_state(world)
    return with_patches(_patches_for(state), function()
      like_collect_subscribe.setup(world.driver.game)
      return dsl.eq(#state.registrations, 3, "注册监听数")
    end)
  end,

  ["触发点赞入口点击"] = function(world)
    return _run_callback(world, LIKE_EVENT)
  end,

  ["触发收藏入口点击"] = function(world)
    return _run_callback(world, COLLECT_EVENT)
  end,

  ["触发订阅入口点击"] = function(world)
    return _run_callback(world, SUBSCRIBE_CLICK_EVENT)
  end,

  ["执行进图订阅检测"] = function(world)
    local state = _ensure_state(world)
    return with_patches(_patches_for(state), function()
      if #state.scheduled == 0 then
        return nil, "未调度进图检测"
      end
      state.scheduled[1].callback()
      return true
    end)
  end,

  ["宿主已订阅本地图作者"] = function(world)
    local state = _ensure_state(world)
    state.role.is_subscribed_map_author = function() return true end
    return true
  end,

  ["宿主未订阅本地图作者"] = function(world)
    local state = _ensure_state(world)
    state.role.is_subscribed_map_author = function() return false end
    return true
  end,

  ["宿主调用将失败"] = function(world)
    local state = _ensure_state(world)
    state.fail_host = true
    state.role.show_like_panel = function() error("panel boom") end
    state.role.is_subscribed_map_author = function() error("subscribe boom") end
    return true
  end,

  ["点赞收藏订阅小窗被打开"] = function(world)
    local state = _ensure_state(world)
    return dsl.eq(#state.panel_calls, 1, "小窗打开次数")
  end,

  ["宿主通过单位事件回发<事件名>"] = function(world, args)
    local state = _ensure_state(world)
    if #state.unit_sends == 0 then
      return nil, "未发送单位事件"
    end
    return dsl.eq(state.unit_sends[#state.unit_sends].event_name, args["事件名"], "回发事件名")
  end,

  ["订阅提示文案为<文案>"] = function(world, args)
    local state = _ensure_state(world)
    if #state.tips_calls == 0 then
      return nil, "未显示提示"
    end
    return dsl.all(
      function() return dsl.eq(state.tips_calls[1].text, args["文案"], "提示文案") end,
      function() return dsl.eq(state.tips_calls[1].duration, 3.0, "提示持续秒数") end
    )
  end,

  ["订阅状态单位事件为<事件名>"] = function(world, args)
    local state = _ensure_state(world)
    if #state.unit_sends == 0 then
      return nil, "未发送订阅状态事件"
    end
    return dsl.eq(state.unit_sends[#state.unit_sends].event_name, args["事件名"], "订阅状态事件名")
  end,

  ["不重复发送订阅状态事件"] = function(world)
    local state = _ensure_state(world)
    return with_patches(_patches_for(state), function()
      local before = #state.unit_sends
      like_collect_subscribe.setup(world.driver.game)
      if #state.scheduled > 0 then
        state.scheduled[1].callback()
      end
      return dsl.eq(#state.unit_sends, before, "订阅状态事件重复发送")
    end)
  end,

  ["未发送任何订阅状态事件"] = function(world)
    local state = _ensure_state(world)
    return dsl.eq(#state.unit_sends, 0, "未订阅不应发送订阅状态事件")
  end,

  ["系统仅记录警告"] = function(world)
    local state = _ensure_state(world)
    return dsl.truthy(#state.warnings > 0, "应记录至少一条警告")
  end,

  ["订阅检测延迟为0.1秒"] = function(world)
    local state = _ensure_state(world)
    if #state.scheduled == 0 then
      return nil, "未调度进图检测"
    end
    return dsl.eq(state.scheduled[1].delay, 0.1, "订阅检测延迟")
  end,
}, { name = "like_collect_subscribe" })
