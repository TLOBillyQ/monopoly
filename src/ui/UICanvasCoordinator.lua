local ui_events = require("src.ui.UIEvents")

local coordinator = {}

coordinator.CANVAS_BASE = "基础屏"
coordinator.CANVAS_PLAYER_CHOICE = "玩家选择屏"
coordinator.CANVAS_TARGET_CHOICE = "位置选择屏"
coordinator.CANVAS_REMOTE_CHOICE = "遥控骰子屏"
coordinator.CANVAS_BUILDING_CHOICE = "建筑升级屏"
coordinator.CANVAS_MARKET = "黑市屏"
coordinator.CANVAS_POPUP = "卡牌展示屏"
coordinator.CANVAS_BANKRUPTCY = "破产展示屏"
coordinator.CANVAS_DEBUG = "调试屏"

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
  for _, name in ipairs(ui_events.canvas_names) do
    local keep_debug = name == coordinator.CANVAS_DEBUG and ui.debug_visible == true
    if name ~= coordinator.CANVAS_BASE and name ~= target_name and not keep_debug then
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
  for _, name in ipairs(ui_events.canvas_names) do
    local keep_debug = name == coordinator.CANVAS_DEBUG and ui.debug_visible == true
    if name ~= coordinator.CANVAS_BASE and name ~= target_name and not keep_debug then
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
