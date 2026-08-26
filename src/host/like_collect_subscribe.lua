local logger = require("src.foundation.log")

local like_collect_subscribe = {}

-- 事件名以编辑器配置为真源；与 view_command 的 SHARE_TASK_OPEN_EVENT 同一约定：
-- 编辑器侧配同名监听触发器，Lua 侧逐字不可漂移。
-- 命名职责单一（参考伪人检查站守卫蛋仔岛 Person.lua 的入口/进度事件名隔离）：
-- evt_not_subscribe = 订阅入口点击的 UI 自定义事件；evt_subscribe = 进图已订阅时
-- 回发的任务进度单位事件（progress_source 同名，宿主任务系统累计）。
local LIKE_EVENT = "evt_click_like"
local COLLECT_EVENT = "evt_add_collection"
local SUBSCRIBE_EVENT = "evt_subscribe"
local SUBSCRIBE_CLICK_EVENT = "evt_not_subscribe"

local SUBSCRIBE_TIPS_TEXT = "点击\"更多\"完成订阅，下次登录领取订阅任务奖励。"
local SUBSCRIBE_TIPS_DURATION = 3.0
local MAP_ENTER_CHECK_DELAY = 0.1

local runtime_field = "__like_collect_subscribe_runtime"

local function _new_runtime()
  return {
    setup_done = false,
    subscribe_sent = false,
  }
end

local function _runtime(game)
  local rt = game[runtime_field]
  if not rt then
    rt = _new_runtime()
    game[runtime_field] = rt
  end
  return rt
end

local function _trigger_ready()
  return RegisterTriggerEvent ~= nil and EVENT ~= nil and EVENT.UI_CUSTOM_EVENT ~= nil
end

local function _role_from_data(data)
  return data and data.role or nil
end

local function _get_ctrl_unit(role)
  if role == nil or type(role.get_ctrl_unit) ~= "function" then
    return nil
  end
  local ok, unit = pcall(role.get_ctrl_unit)
  if not ok or unit == nil then
    return nil
  end
  return unit
end

local function _send_unit_event(role, event_name)
  local unit = _get_ctrl_unit(role)
  if unit == nil then
    logger.warn("like_collect_subscribe unit missing:", event_name)
    return false
  end
  if LuaAPI == nil or type(LuaAPI.unit_send_custom_event) ~= "function" then
    logger.warn("like_collect_subscribe LuaAPI missing:", event_name)
    return false
  end
  local ok, err = pcall(LuaAPI.unit_send_custom_event, unit, event_name, {})
  if not ok then
    logger.warn("like_collect_subscribe send failed:", event_name, tostring(err))
    return false
  end
  return true
end

local function _show_like_panel(role, event_name)
  if role == nil or type(role.show_like_panel) ~= "function" then
    logger.warn("like_collect_subscribe show_like_panel missing:", event_name)
    return
  end
  local ok, err = pcall(role.show_like_panel)
  if not ok then
    logger.warn("like_collect_subscribe show_like_panel failed:", event_name, tostring(err))
  end
end

local function _handle_like_or_collect(event_name, data)
  local role = _role_from_data(data)
  _show_like_panel(role, event_name)
  if role ~= nil then
    _send_unit_event(role, event_name)
  end
end

local function _show_tips(text, duration)
  if GlobalAPI == nil or type(GlobalAPI.show_tips) ~= "function" then
    logger.warn("like_collect_subscribe GlobalAPI.show_tips missing")
    return
  end
  local ok, err = pcall(GlobalAPI.show_tips, text, duration)
  if not ok then
    logger.warn("like_collect_subscribe show_tips failed:", tostring(err))
  end
end

local function _handle_subscribe_click(data)
  local role = _role_from_data(data)
  _show_like_panel(role, SUBSCRIBE_CLICK_EVENT)
  _show_tips(SUBSCRIBE_TIPS_TEXT, SUBSCRIBE_TIPS_DURATION)
end

local function _all_valid_roles()
  if GameAPI == nil or type(GameAPI.get_all_valid_roles) ~= "function" then
    return nil
  end
  local ok, roles = pcall(GameAPI.get_all_valid_roles)
  if not ok or type(roles) ~= "table" then
    return nil
  end
  return roles
end

local function _first_valid_role()
  local roles = _all_valid_roles()
  if roles == nil or #roles == 0 then
    return nil
  end
  return roles[1]
end

-- 进图订阅状态：已订阅返回进度事件名 evt_subscribe；未订阅返回 nil——
-- 未订阅不发任何事件（与参考实现一致，evt_not_subscribe 只作入口点击事件名）。
local function _subscription_event_name(role)
  if type(role.is_subscribed_map_author) ~= "function" then
    logger.warn("like_collect_subscribe is_subscribed_map_author missing")
    return nil
  end
  local ok, subscribed = pcall(role.is_subscribed_map_author)
  if not ok then
    logger.warn("like_collect_subscribe subscription check failed:", tostring(subscribed))
    return nil
  end
  if not subscribed then
    return nil
  end
  return SUBSCRIBE_EVENT
end

local function _check_subscription(game)
  local rt = _runtime(game)
  if rt.subscribe_sent then
    return
  end
  local role = _first_valid_role()
  if role == nil then
    logger.warn("like_collect_subscribe no valid role for subscription check")
    return
  end
  local event_name = _subscription_event_name(role)
  if event_name == nil then
    return
  end
  -- 只锁存成功发送：瞬时失败（unit 缺失/宿主抛错）不吞掉，下次检测可重试。
  if _send_unit_event(role, event_name) then
    rt.subscribe_sent = true
  end
end

local function _register_listener(event_name, callback)
  RegisterTriggerEvent({ EVENT.UI_CUSTOM_EVENT, event_name }, callback)
end

function like_collect_subscribe.setup(game)
  local rt = _runtime(game)
  if rt.setup_done then
    return
  end
  if not _trigger_ready() then
    logger.warn("like_collect_subscribe host event contract missing")
    return
  end

  _register_listener(LIKE_EVENT, function(_, _, data)
    _handle_like_or_collect(LIKE_EVENT, data or {})
  end)
  _register_listener(COLLECT_EVENT, function(_, _, data)
    _handle_like_or_collect(COLLECT_EVENT, data or {})
  end)
  _register_listener(SUBSCRIBE_CLICK_EVENT, function(_, _, data)
    _handle_subscribe_click(data or {})
  end)

  if type(SetTimeOut) == "function" then
    local ok, err = pcall(SetTimeOut, MAP_ENTER_CHECK_DELAY, function()
      _check_subscription(game)
    end)
    if not ok then
      logger.warn("like_collect_subscribe schedule check failed:", tostring(err))
    end
  else
    logger.warn("like_collect_subscribe SetTimeOut missing")
  end

  rt.setup_done = true
end

-- Test seam exports
like_collect_subscribe._runtime = _runtime
like_collect_subscribe._handle_like_or_collect = _handle_like_or_collect
like_collect_subscribe._handle_subscribe_click = _handle_subscribe_click
like_collect_subscribe._check_subscription = _check_subscription

return like_collect_subscribe

--[[ mutate4lua-manifest
version=4
projectHash=2a7ffc60e2b961d4
scope.0.id=chunk:src/host/like_collect_subscribe.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=212
scope.0.semanticHash=6007bcb36249058a
scope.1.id=function:_new_runtime
scope.1.kind=function
scope.1.startLine=21
scope.1.endLine=26
scope.1.semanticHash=856e1e6b781364d0
scope.2.id=function:_runtime
scope.2.kind=function
scope.2.startLine=28
scope.2.endLine=35
scope.2.semanticHash=57a1d475facd493e
scope.3.id=function:_trigger_ready
scope.3.kind=function
scope.3.startLine=37
scope.3.endLine=39
scope.3.semanticHash=fc7b42f5cdff62e3
scope.4.id=function:_role_from_data
scope.4.kind=function
scope.4.startLine=41
scope.4.endLine=43
scope.4.semanticHash=616a2ca60599c94f
scope.5.id=function:_get_ctrl_unit
scope.5.kind=function
scope.5.startLine=45
scope.5.endLine=54
scope.5.semanticHash=54e7629486dbfc7a
scope.6.id=function:_send_unit_event
scope.6.kind=function
scope.6.startLine=56
scope.6.endLine=72
scope.6.semanticHash=5ef96abc8c223cf7
scope.7.id=function:_show_like_panel
scope.7.kind=function
scope.7.startLine=74
scope.7.endLine=83
scope.7.semanticHash=3453b1b72d95ed5d
scope.8.id=function:_handle_like_or_collect
scope.8.kind=function
scope.8.startLine=85
scope.8.endLine=91
scope.8.semanticHash=1a5e91abcf51c10e
scope.9.id=function:_show_tips
scope.9.kind=function
scope.9.startLine=93
scope.9.endLine=102
scope.9.semanticHash=dc9dd245ade59faf
scope.10.id=function:_handle_subscribe_click
scope.10.kind=function
scope.10.startLine=104
scope.10.endLine=108
scope.10.semanticHash=25ef0e616b374c5b
scope.11.id=function:_all_valid_roles
scope.11.kind=function
scope.11.startLine=110
scope.11.endLine=119
scope.11.semanticHash=ecf7e8abe23552d0
scope.12.id=function:_first_valid_role
scope.12.kind=function
scope.12.startLine=121
scope.12.endLine=127
scope.12.semanticHash=aaedce70aa7182a6
scope.13.id=function:_subscription_event_name
scope.13.kind=function
scope.13.startLine=131
scope.13.endLine=145
scope.13.semanticHash=74d19a619d089346
scope.14.id=function:_check_subscription
scope.14.kind=function
scope.14.startLine=147
scope.14.endLine=165
scope.14.semanticHash=809640f9da5bee31
scope.15.id=function:_register_listener
scope.15.kind=function
scope.15.startLine=167
scope.15.endLine=169
scope.15.semanticHash=2866f9cd410bd3a1
scope.16.id=function:like_collect_subscribe.setup
scope.16.kind=function
scope.16.startLine=171
scope.16.endLine=203
scope.16.semanticHash=7cb4d14f4b67f4f3
scope.17.id=function:<anonymous>
scope.17.kind=function
scope.17.startLine=181
scope.17.endLine=183
scope.17.semanticHash=6a2557df1ada7ba6
scope.18.id=function:<anonymous>#2
scope.18.kind=function
scope.18.startLine=184
scope.18.endLine=186
scope.18.semanticHash=6a2557df1ada7ba6
scope.19.id=function:<anonymous>#3
scope.19.kind=function
scope.19.startLine=187
scope.19.endLine=189
scope.19.semanticHash=c358d28727a6078d
scope.20.id=function:<anonymous>#4
scope.20.kind=function
scope.20.startLine=192
scope.20.endLine=194
scope.20.semanticHash=600a75ce96a391b3
]]
