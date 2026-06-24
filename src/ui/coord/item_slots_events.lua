local runtime = require("src.ui.render.runtime_ui")
local ui_events = require("src.ui.coord.ui_events")

local M = {}

local function _outline_setter(method_name)
  return function(ui, outline_name, value)
    if outline_name and ui and ui[method_name] then
      ui[method_name](ui, outline_name, value == true)
    end
  end
end

local _set_outline_visible = _outline_setter("set_visible")
local _set_outline_touch_enabled = _outline_setter("set_touch_enabled")

local _empty_event_payload = {}

local function _emit_ui_event(event_name)
  local role = runtime.get_client_role()
  if role then
    ui_events.send_to_role(role, event_name, _empty_event_payload)
    return
  end
  ui_events.send_to_all(event_name, _empty_event_payload)
end

local function _emit_slot_animation(index, event_prefix)
  _emit_ui_event(event_prefix .. tostring(index))
end

local _sig_parts = {}

function M.build_pickable_signature(slot_pickable)
  local n = 0
  for index, can_pick in ipairs(slot_pickable) do
    if can_pick then
      n = n + 1
      _sig_parts[n] = tostring(index)
    end
  end
  for i = n + 1, #_sig_parts do
    _sig_parts[i] = nil
  end
  return table.concat(_sig_parts, ",")
end

function M.emit_global_reset_animation()
  _emit_ui_event("重置高亮")
end

function M.emit_pickable_slot_animation(slot_pickable)
  M.emit_global_reset_animation()
  for index, can_pick in ipairs(slot_pickable) do
    if not can_pick then
      _emit_slot_animation(index, "重置高亮道具槽位牌")
    end
  end
  for index, can_pick in ipairs(slot_pickable) do
    if can_pick then
      _emit_slot_animation(index, "高亮道具槽位牌")
    end
  end
end

function M.apply_outline_state(ui, outlines, slot_pickable, visible_enabled)
  local enabled = visible_enabled == true
  for index, outline_name in ipairs(outlines) do
    local can_pick = slot_pickable[index] == true
    local visible = enabled and can_pick
    _set_outline_visible(ui, outline_name, visible)
    _set_outline_touch_enabled(ui, outline_name, visible)
  end
end

return M
