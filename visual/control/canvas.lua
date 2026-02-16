local ui_events = require("visual.events")
local runtime = require("visual.runtime")
local ui_nodes = require("visual.nodes")

local coordinator = {}

coordinator.CANVAS_BASE = ui_nodes.canvas.base
coordinator.CANVAS_PLAYER_CHOICE = ui_nodes.canvas.player_choice
coordinator.CANVAS_TARGET_CHOICE = ui_nodes.canvas.target_choice
coordinator.CANVAS_REMOTE_CHOICE = ui_nodes.canvas.remote_choice
coordinator.CANVAS_BUILDING_CHOICE = ui_nodes.canvas.building_choice
coordinator.CANVAS_MARKET = ui_nodes.canvas.market
coordinator.CANVAS_POPUP = ui_nodes.canvas.popup
coordinator.CANVAS_BANKRUPTCY = ui_nodes.canvas.bankruptcy
coordinator.CANVAS_DEBUG = ui_nodes.canvas.debug

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
  if key == "building" then
    return coordinator.CANVAS_BUILDING_CHOICE
  end
  return nil
end

function coordinator.switch(ui, target)
  assert(ui ~= nil, "missing ui")
  local target_name = target or coordinator.CANVAS_BASE
  local debug_by_role = ui.debug_visible_by_role
  local keep_debug = ui.debug_visible == true
  if keep_debug ~= true and type(debug_by_role) == "table" then
    for _, enabled in pairs(debug_by_role) do
      if enabled == true then
        keep_debug = true
        break
      end
    end
  end
  for _, name in ipairs(ui_events.canvas_names) do
    local keep_debug_canvas = name == coordinator.CANVAS_DEBUG and keep_debug
    if name ~= coordinator.CANVAS_BASE and name ~= target_name and not keep_debug_canvas then
      local hide_event = ui_events.hide[name]
      if hide_event then
        ui_events.send_to_all(hide_event, {})
      end
    end
  end
  local base_event = ui_events.show[coordinator.CANVAS_BASE]
  if base_event then
    ui_events.send_to_all(base_event, {})
  end
  if target_name ~= coordinator.CANVAS_BASE then
    local target_event = ui_events.show[target_name]
    if target_event then
      ui_events.send_to_all(target_event, {})
    end
  end
end

function coordinator.switch_for_role(ui, target, role)
  assert(ui ~= nil, "missing ui")
  assert(role ~= nil, "missing role")
  local target_name = target or coordinator.CANVAS_BASE
  local role_id = runtime.resolve_role_id(role) or tostring(role)
  local debug_by_role = ui.debug_visible_by_role
  local keep_debug = false
  if type(debug_by_role) == "table" then
    keep_debug = debug_by_role[role_id] == true
  end
  for _, name in ipairs(ui_events.canvas_names) do
    local keep_debug_canvas = name == coordinator.CANVAS_DEBUG and keep_debug
    if name ~= coordinator.CANVAS_BASE and name ~= target_name and not keep_debug_canvas then
      local hide_event = ui_events.hide[name]
      if hide_event then
        ui_events.send_to_role(role, hide_event, {})
      end
    end
  end
  local base_event = ui_events.show[coordinator.CANVAS_BASE]
  if base_event then
    ui_events.send_to_role(role, base_event, {})
  end
  if target_name ~= coordinator.CANVAS_BASE then
    local target_event = ui_events.show[target_name]
    if target_event then
      ui_events.send_to_role(role, target_event, {})
    end
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
    if target == choice_canvas then
      return choice_canvas
    end
    return choice_canvas
  end
  return coordinator.CANVAS_BASE
end

return coordinator
