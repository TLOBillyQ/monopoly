local ui_events = require("src.ui.ctl.ui_events")
local runtime = require("src.ui.render.runtime_ui")
local base_nodes = require("src.ui.schema.base")
local always_show_nodes = require("src.ui.schema.always_show")
local player_choice_nodes = require("src.ui.schema.player_choice")
local target_choice_nodes = require("src.ui.schema.target_choice")
local remote_choice_nodes = require("src.ui.schema.remote_choice")
local secondary_confirm_nodes = require("src.ui.schema.secondary_confirm")
local market_nodes = require("src.ui.schema.market")
local popup_nodes = require("src.ui.schema.popup")
local bankruptcy_nodes = require("src.ui.schema.bankruptcy")
local debug_nodes = require("src.ui.schema.debug")
local role_id_utils = require("src.core.utils.role_id")

local coordinator = {}

coordinator.CANVAS_BASE = base_nodes.canvas
coordinator.CANVAS_ALWAYS_SHOW = always_show_nodes.canvas
coordinator.CANVAS_PLAYER_CHOICE = player_choice_nodes.canvas
coordinator.CANVAS_TARGET_CHOICE = target_choice_nodes.canvas
coordinator.CANVAS_REMOTE_CHOICE = remote_choice_nodes.canvas
coordinator.CANVAS_SECONDARY_CONFIRM = secondary_confirm_nodes.canvas
coordinator.CANVAS_MARKET = market_nodes.canvas
coordinator.CANVAS_POPUP = popup_nodes.canvas
coordinator.CANVAS_BANKRUPTCY = bankruptcy_nodes.canvas
coordinator.CANVAS_DEBUG = debug_nodes.canvas

local function _resolve_choice_canvas(ui)
  if not ui or not ui.choice_active then
    return nil
  end
  local key = ui.active_choice_screen_key
  if key == "player" then
    return coordinator.CANVAS_PLAYER_CHOICE
  end
  if key == "target" then
    return coordinator.CANVAS_TARGET_CHOICE
  end
  if key == "remote" then
    return coordinator.CANVAS_REMOTE_CHOICE
  end
  if key == "secondary_confirm" then
    return coordinator.CANVAS_SECONDARY_CONFIRM
  end
  return nil
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
    and name ~= coordinator.CANVAS_ALWAYS_SHOW
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
  local always_show_event = ui_events.show[coordinator.CANVAS_ALWAYS_SHOW]
  if always_show_event then
    send_fn(always_show_event, {})
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
    if target == choice_canvas then
      return choice_canvas
    end
    return choice_canvas
  end
  return coordinator.CANVAS_BASE
end

return coordinator
