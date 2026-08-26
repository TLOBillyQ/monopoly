local logger = require("src.foundation.log")
local host_types = require("src.foundation.host_types")
local role_id_utils = require("src.foundation.identity")
local runtime = require("src.ui.render.support.runtime_ui")
local canvas = require("src.ui.coord.canvas_coordinator")
local ui_events = require("src.ui.coord.ui_events")
local ui_event_state = require("src.ui.coord.event_state")
local actor_context = require("src.ui.coord.actor_context")
local market = require("src.ui.screens.market")
local popup_presenter = require("src.ui.coord.popup_presenter")
local event_log_view = require("src.ui.coord.event_log_view")
local skin_panel = require("src.ui.screens.skin_panel")
local item_atlas = require("src.ui.screens.item_atlas")
local skin_gallery = require("src.ui.screens.skin_panel.skin_gallery")
local command_policy = require("src.ui.input.command_policy")
local runtime_ports = require("src.foundation.ports.runtime_ports")

local view_command_ports = {}

-- 分享按钮点击时发送的全局自定义事件名（#458 真机实证：Lua/Editor API 面无
-- 活动面板直接入口，全局事件是唯一通路；单位通道 unit_send_custom_event
-- 实测无人接收）。编辑器侧配同名监听触发器打开分享任务面板，事件名以编辑器
-- 配置为准，逐字不可漂移。
local SHARE_TASK_OPEN_EVENT = "打开分享任务"

local function _resolve_toggle_role(state, intent)
  local actor_role_id = role_id_utils.normalize(intent and intent.actor_role_id or nil)
  if actor_role_id == nil then
    logger.warn("toggle_action_log missing actor_role_id")
    return nil, nil, true
  end
  local active_role = actor_context.resolve_role_by_id(actor_role_id)
  local next_enabled = not ui_event_state.resolve_event_log_enabled(state, actor_role_id)
  return actor_role_id, active_role, next_enabled
end

local function _can_toggle_action_log(state)
  return state and state.ui ~= nil
end

local function _should_abort_toggle(actor_role_id, next_enabled)
  return next_enabled == true and actor_role_id == nil
end

local function _hide_debug_canvas(active_role)
  local hide_event = ui_events.hide[canvas.CANVAS_DEBUG]
  if hide_event then
    ui_events.send_to_role(active_role, hide_event, {})
  end
end

local function _sync_debug_canvas(ui, active_role, next_enabled)
  if next_enabled then
    canvas.switch_for_role(ui, canvas.CANVAS_DEBUG, active_role)
    return
  end
  _hide_debug_canvas(active_role)
end

local function _warn_missing_debug_channel(active_role, actor_role_id, next_enabled)
  if not next_enabled then
    return
  end
  -- active_role 是宿主 Role，type() 不是 "table"（#266）；用 type 把门会恒假，
  -- 让每次开关都误报「没有事件通道」。
  if host_types.method(active_role, "send_ui_custom_event") ~= nil then
    return
  end
  logger.warn("toggle_action_log missing role event channel:", tostring(actor_role_id))
end

local function _toggle_action_log(state, intent, sync_event_log)
  if not _can_toggle_action_log(state) then
    return true
  end
  local ui = state.ui
  local actor_role_id, active_role, next_enabled = _resolve_toggle_role(state, intent)
  if _should_abort_toggle(actor_role_id, next_enabled) then
    return true
  end
  event_log_view.set_event_log_visible_for_role(state, active_role, next_enabled)
  if next_enabled and type(sync_event_log) == "function" then
    sync_event_log(state)
  end
  _warn_missing_debug_channel(active_role, actor_role_id, next_enabled)
  _sync_debug_canvas(ui, active_role, next_enabled)
  runtime.set_client_role(nil)
  return true
end

local function _panel_action_handler(module)
  return function(state, intent)
    module.handle_action(state, intent.action, intent.actor_role_id)
    return true
  end
end

function view_command_ports.build(dependencies)
  local sync_event_log = dependencies and dependencies.sync_event_log
  local handlers = {
    toggle_action_log = function(state, intent)
      return _toggle_action_log(state, intent, sync_event_log)
    end,
    open_skin_panel = function(state, intent)
      skin_gallery.open_skin(state, intent.actor_role_id)
      return true
    end,
    open_gallery_panel = function(state, intent)
      skin_gallery.open_gallery(state, intent.actor_role_id)
      return true
    end,
    skin_panel_action = _panel_action_handler(skin_panel),
    item_atlas_action = _panel_action_handler(item_atlas),
    skin_gallery_action = _panel_action_handler(skin_gallery),
    market_select = function(state, intent)
      market.select_market_option(state, intent.option_id)
      return true
    end,
    popup_confirm = function(state, intent)
      popup_presenter.dismiss_popup(state, intent and intent.actor_role_id or nil)
      return true
    end,
    -- 分享按钮：每次点击都发全局自定义事件「打开分享任务」请求宿主打开分享
    -- 任务面板，不锁存；发送通道失败（未配置/宿主抛错，默认实现内部 pcall）
    -- 只 warn 降级，不影响视图命令本身成立。全局事件无角色参数，intent 的
    -- actor_role_id 此处不再需要。
    open_share_panel = function(state, intent)
      if not runtime_ports.emit_event(SHARE_TASK_OPEN_EVENT, {}) then
        logger.warn("share button emit event failed:", SHARE_TASK_OPEN_EVENT)
      end
      return true
    end,
  }
  return {
    dispatch = function(state, intent)
      local handler_key = command_policy.port_handler(intent)
      if handler_key == nil then
        return false
      end
      local handler = handlers[handler_key]
      return handler and handler(state, intent) or false
    end,
  }
end

return view_command_ports

--[[ mutate4lua-manifest
version=4
projectHash=0f9ed4d549185852
scope.0.id=chunk:src/ui/ports/view_command.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=147
scope.0.semanticHash=c28d420106e31bfb
scope.1.id=function:_resolve_toggle_role
scope.1.kind=function
scope.1.startLine=26
scope.1.endLine=35
scope.1.semanticHash=e10c0f3a361967aa
scope.2.id=function:_can_toggle_action_log
scope.2.kind=function
scope.2.startLine=37
scope.2.endLine=39
scope.2.semanticHash=46fa40dafd4596af
scope.3.id=function:_should_abort_toggle
scope.3.kind=function
scope.3.startLine=41
scope.3.endLine=43
scope.3.semanticHash=4b7092c7e67a1c70
scope.4.id=function:_hide_debug_canvas
scope.4.kind=function
scope.4.startLine=45
scope.4.endLine=50
scope.4.semanticHash=dda67544f98a9300
scope.5.id=function:_sync_debug_canvas
scope.5.kind=function
scope.5.startLine=52
scope.5.endLine=58
scope.5.semanticHash=26635d6274b2da91
scope.6.id=function:_warn_missing_debug_channel
scope.6.kind=function
scope.6.startLine=60
scope.6.endLine=70
scope.6.semanticHash=ad54918f84a4f982
scope.7.id=function:_toggle_action_log
scope.7.kind=function
scope.7.startLine=72
scope.7.endLine=89
scope.7.semanticHash=0d5706cfb1adc5e0
scope.8.id=function:_panel_action_handler
scope.8.kind=function
scope.8.startLine=91
scope.8.endLine=96
scope.8.semanticHash=60952dd9ba85d014
scope.9.id=function:<anonymous>
scope.9.kind=function
scope.9.startLine=92
scope.9.endLine=95
scope.9.semanticHash=e4557252ff6a183b
scope.10.id=function:view_command_ports.build
scope.10.kind=function
scope.10.startLine=98
scope.10.endLine=144
scope.10.semanticHash=ba28eb7d0162fb84
scope.11.id=function:<anonymous>#2
scope.11.kind=function
scope.11.startLine=101
scope.11.endLine=103
scope.11.semanticHash=b24edc9efb4ea62a
scope.12.id=function:<anonymous>#3
scope.12.kind=function
scope.12.startLine=104
scope.12.endLine=107
scope.12.semanticHash=0b9d34c8459cab99
scope.13.id=function:<anonymous>#4
scope.13.kind=function
scope.13.startLine=108
scope.13.endLine=111
scope.13.semanticHash=0b9d34c8459cab99
scope.14.id=function:<anonymous>#5
scope.14.kind=function
scope.14.startLine=115
scope.14.endLine=118
scope.14.semanticHash=0b9d34c8459cab99
scope.15.id=function:<anonymous>#6
scope.15.kind=function
scope.15.startLine=119
scope.15.endLine=122
scope.15.semanticHash=ab17981b2b1a3126
scope.16.id=function:<anonymous>#7
scope.16.kind=function
scope.16.startLine=127
scope.16.endLine=132
scope.16.semanticHash=e48b251ef67c260e
scope.17.id=function:<anonymous>#8
scope.17.kind=function
scope.17.startLine=135
scope.17.endLine=142
scope.17.semanticHash=b44f8f645a06e174
]]
