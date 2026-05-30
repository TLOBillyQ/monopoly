local logger = require("src.foundation.log")
local role_id_utils = require("src.foundation.identity")
local runtime = require("src.ui.render.runtime_ui")
local canvas = require("src.ui.coord.canvas_coordinator")
local ui_events = require("src.ui.coord.ui_events")
local ui_event_state = require("src.ui.coord.event_state")
local actor_context = require("src.ui.coord.actor_context")
local market = require("src.ui.coord.market")
local modal = require("src.ui.coord.modal")
local event_log_view = require("src.ui.coord.event_log_view")
local skin_panel = require("src.ui.coord.skin_panel")
local item_atlas = require("src.ui.coord.item_atlas")
local skin_gallery = require("src.ui.coord.skin_gallery")

local view_command_ports = {}

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
  if type(active_role) == "table" and type(active_role.send_ui_custom_event) == "function" then
    return
  end
  logger.warn("toggle_action_log missing role event channel:", tostring(actor_role_id))
end

local function _toggle_action_log(state, intent)
  if not _can_toggle_action_log(state) then
    return true
  end
  local ui = state.ui
  local actor_role_id, active_role, next_enabled = _resolve_toggle_role(state, intent)
  if _should_abort_toggle(actor_role_id, next_enabled) then
    return true
  end
  event_log_view.set_event_log_visible_for_role(state, active_role, next_enabled)
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

function view_command_ports.build()
  local handlers = {
    toggle_action_log = function(state, intent)
      return _toggle_action_log(state, intent)
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
    popup_confirm = function(state)
      modal.close_popup(state)
      return true
    end,
  }
  return {
    dispatch = function(state, intent)
      local intent_type = intent and intent.type or nil
      if intent_type == nil then
        return false
      end
      local handler = handlers[intent_type]
      return handler and handler(state, intent) or false
    end,
  }
end

return view_command_ports

--[[ mutate4lua-manifest
version=2
projectHash=7f1f14e9b1c593f5
scope.0.id=chunk:src/ui/ports/view_command.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=122
scope.0.semanticHash=97b55bf88c16a6d5
scope.1.id=function:_resolve_toggle_role:17
scope.1.kind=function
scope.1.startLine=17
scope.1.endLine=26
scope.1.semanticHash=5560ab2d8150c50c
scope.2.id=function:_can_toggle_action_log:28
scope.2.kind=function
scope.2.startLine=28
scope.2.endLine=30
scope.2.semanticHash=5b34e8d335e82ecf
scope.3.id=function:_should_abort_toggle:32
scope.3.kind=function
scope.3.startLine=32
scope.3.endLine=34
scope.3.semanticHash=07139efae95f5971
scope.4.id=function:_hide_debug_canvas:36
scope.4.kind=function
scope.4.startLine=36
scope.4.endLine=41
scope.4.semanticHash=4a747bdbbc35aba5
scope.5.id=function:_sync_debug_canvas:43
scope.5.kind=function
scope.5.startLine=43
scope.5.endLine=49
scope.5.semanticHash=1ff79204b3cb31db
scope.6.id=function:_warn_missing_debug_channel:51
scope.6.kind=function
scope.6.startLine=51
scope.6.endLine=59
scope.6.semanticHash=5337caf7cdaf192f
scope.7.id=function:_toggle_action_log:61
scope.7.kind=function
scope.7.startLine=61
scope.7.endLine=75
scope.7.semanticHash=bcce837c79f5b8e1
scope.8.id=function:anonymous@78:78
scope.8.kind=function
scope.8.startLine=78
scope.8.endLine=81
scope.8.semanticHash=e392e628b04267df
scope.9.id=function:_panel_action_handler:77
scope.9.kind=function
scope.9.startLine=77
scope.9.endLine=82
scope.9.semanticHash=89efe58fea3c6b3c
scope.10.id=function:anonymous@86:86
scope.10.kind=function
scope.10.startLine=86
scope.10.endLine=88
scope.10.semanticHash=fa3bbf91e0a989f5
scope.11.id=function:anonymous@89:89
scope.11.kind=function
scope.11.startLine=89
scope.11.endLine=92
scope.11.semanticHash=40d7208bd025bc7e
scope.12.id=function:anonymous@93:93
scope.12.kind=function
scope.12.startLine=93
scope.12.endLine=96
scope.12.semanticHash=eb60d122dd798ecf
scope.13.id=function:anonymous@100:100
scope.13.kind=function
scope.13.startLine=100
scope.13.endLine=103
scope.13.semanticHash=4aa81e4ed3f9ef64
scope.14.id=function:anonymous@104:104
scope.14.kind=function
scope.14.startLine=104
scope.14.endLine=107
scope.14.semanticHash=5af31d9eb98b25f0
scope.15.id=function:anonymous@110:110
scope.15.kind=function
scope.15.startLine=110
scope.15.endLine=117
scope.15.semanticHash=197d7d0446b05dfb
scope.16.id=function:view_command_ports.build:84
scope.16.kind=function
scope.16.startLine=84
scope.16.endLine=119
scope.16.semanticHash=0c74a1477771c67c
]]
