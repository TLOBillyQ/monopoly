local ui_events = require("src.ui.coord.ui_events")
local runtime = require("src.ui.render.runtime_ui")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local base_nodes = require("src.ui.schema.base")
local permanent_nodes = require("src.ui.schema.permanent")
local player_choice_nodes = require("src.ui.schema.player_choice")
local target_choice_nodes = require("src.ui.schema.target_choice")
local remote_choice_nodes = require("src.ui.schema.remote_choice")
local secondary_confirm_nodes = require("src.ui.schema.secondary_confirm")
local market_nodes = require("src.ui.schema.market")
local popup_nodes = require("src.ui.schema.popup")
local bankruptcy_nodes = require("src.ui.schema.bankruptcy")
local debug_nodes = require("src.ui.schema.debug")
local role_id_utils = require("src.foundation.identity")

local coordinator = {}

coordinator.CANVAS_BASE = base_nodes.canvas
coordinator.CANVAS_PERMANENT = permanent_nodes.canvas
coordinator.CANVAS_PLAYER_CHOICE = player_choice_nodes.canvas
coordinator.CANVAS_TARGET_CHOICE = target_choice_nodes.canvas
coordinator.CANVAS_REMOTE_CHOICE = remote_choice_nodes.canvas
coordinator.CANVAS_SECONDARY_CONFIRM = secondary_confirm_nodes.canvas
coordinator.CANVAS_MARKET = market_nodes.canvas
coordinator.CANVAS_POPUP = popup_nodes.canvas
coordinator.CANVAS_BANKRUPTCY = bankruptcy_nodes.canvas
coordinator.CANVAS_DEBUG = debug_nodes.canvas

local _CHOICE_CANVAS_BY_KEY = {
  player            = coordinator.CANVAS_PLAYER_CHOICE,
  target            = coordinator.CANVAS_TARGET_CHOICE,
  remote            = coordinator.CANVAS_REMOTE_CHOICE,
  secondary_confirm = coordinator.CANVAS_SECONDARY_CONFIRM,
}

local function _resolve_choice_canvas(ui)
  if not ui or not ui.choice_active then return nil end
  return _CHOICE_CANVAS_BY_KEY[ui.active_choice_screen_key]
end

local function _has_any_debug_canvas(ui)
  local debug_by_role = ui.debug_visible_by_role
  if type(debug_by_role) == "table" then
    for _, enabled in pairs(debug_by_role) do
      if enabled == true then
        return true
      end
    end
  end
  return false
end

local function _should_hide_canvas(name, target_name, keep_debug)
  local keep_debug_canvas = name == coordinator.CANVAS_DEBUG and keep_debug
  return name ~= coordinator.CANVAS_BASE
    and name ~= coordinator.CANVAS_PERMANENT
    and name ~= target_name
    and not keep_debug_canvas
end

local function _hide_other_canvases(target_name, keep_debug, send_fn)
  for _, name in ipairs(ui_events.canvas_names) do
    if _should_hide_canvas(name, target_name, keep_debug) then
      local hide_event = ui_events.hide[name]
      if hide_event then
        send_fn(hide_event, {})
      end
    end
  end
end

local function _show_canvas_set(target_name, send_fn)
  local base_event = ui_events.show[coordinator.CANVAS_BASE]
  if base_event then
    send_fn(base_event, {})
  end
  local permanent_event = ui_events.show[coordinator.CANVAS_PERMANENT]
  if permanent_event then
    send_fn(permanent_event, {})
  end
  if target_name ~= coordinator.CANVAS_BASE then
    local target_event = ui_events.show[target_name]
    if target_event then
      send_fn(target_event, {})
    end
  end
end

function coordinator.switch(ui, target)
  assert(ui ~= nil, "missing ui")
  local target_name = target or coordinator.CANVAS_BASE
  local keep_debug = _has_any_debug_canvas(ui)
  _hide_other_canvases(target_name, keep_debug, ui_events.send_to_all)
  _show_canvas_set(target_name, ui_events.send_to_all)
end

function coordinator.switch_for_role(ui, target, role)
  assert(ui ~= nil, "missing ui")
  assert(role ~= nil, "missing role")
  local target_name = target or coordinator.CANVAS_BASE
  local role_id = role_id_utils.normalize(runtime.resolve_role_id(role) or tostring(role))
  local debug_by_role = ui.debug_visible_by_role
  local keep_debug = false
  if type(debug_by_role) == "table" then
    keep_debug = role_id_utils.read(debug_by_role, role_id) == true
  end
  _hide_other_canvases(target_name, keep_debug, function(event_name, payload)
    ui_events.send_to_role(role, event_name, payload)
  end)
  _show_canvas_set(target_name, function(event_name, payload)
    ui_events.send_to_role(role, event_name, payload)
  end)
end

function coordinator.switch_by_role_id(ui, target, role_id)
  if not ui then
    return
  end
  local role = runtime_ports.resolve_role(role_id)
  if role then
    coordinator.switch_for_role(ui, target, role)
  else
    coordinator.switch(ui, target)
  end
end

function coordinator.resolve_popup_return_canvas(ui)
  if ui.market_active then
    return coordinator.CANVAS_MARKET
  end
  local choice_canvas = _resolve_choice_canvas(ui)
  if choice_canvas then
    return choice_canvas
  end
  return coordinator.CANVAS_BASE
end

function coordinator.resolve_canvas_after_popup(ui, target)
  if target == coordinator.CANVAS_MARKET and ui.market_active then
    return coordinator.CANVAS_MARKET
  end
  local choice_canvas = _resolve_choice_canvas(ui)
  if choice_canvas then
    return choice_canvas
  end
  return coordinator.CANVAS_BASE
end

return coordinator

--[[ mutate4lua-manifest
version=2
projectHash=712c090d3ed9dd1d
scope.0.id=chunk:src/ui/coord/canvas_coordinator.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=148
scope.0.semanticHash=9a4722e5bb9b06e6
scope.1.id=function:_resolve_choice_canvas:36
scope.1.kind=function
scope.1.startLine=36
scope.1.endLine=39
scope.1.semanticHash=bc3c67f5c89b645c
scope.2.id=function:_should_hide_canvas:53
scope.2.kind=function
scope.2.startLine=53
scope.2.endLine=59
scope.2.semanticHash=a39660c0b258f701
scope.3.id=function:_show_canvas_set:72
scope.3.kind=function
scope.3.startLine=72
scope.3.endLine=87
scope.3.semanticHash=e89635b613584d17
scope.4.id=function:coordinator.switch:89
scope.4.kind=function
scope.4.startLine=89
scope.4.endLine=95
scope.4.semanticHash=98b09bb287d80ae1
scope.5.id=function:anonymous@107:107
scope.5.kind=function
scope.5.startLine=107
scope.5.endLine=109
scope.5.semanticHash=6add05f2cba6faf9
scope.6.id=function:anonymous@110:110
scope.6.kind=function
scope.6.startLine=110
scope.6.endLine=112
scope.6.semanticHash=6add05f2cba6faf9
scope.7.id=function:coordinator.switch_for_role:97
scope.7.kind=function
scope.7.startLine=97
scope.7.endLine=113
scope.7.semanticHash=297aff38525e4b80
scope.8.id=function:coordinator.switch_by_role_id:115
scope.8.kind=function
scope.8.startLine=115
scope.8.endLine=123
scope.8.semanticHash=4e878b0381def1d1
scope.9.id=function:coordinator.resolve_popup_return_canvas:125
scope.9.kind=function
scope.9.startLine=125
scope.9.endLine=134
scope.9.semanticHash=221a15460f81f40d
scope.10.id=function:coordinator.resolve_canvas_after_popup:136
scope.10.kind=function
scope.10.startLine=136
scope.10.endLine=145
scope.10.semanticHash=065980b055a1cfd9
]]
