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

--[[ mutate4lua-manifest
version=2
projectHash=32627f9be9ddc303
scope.0.id=chunk:src/ui/coord/item_slots_events.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=77
scope.0.semanticHash=dc66b1cc774ba11c
scope.0.lastMutatedAt=2026-06-24T20:10:10Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=26
scope.0.lastMutationKilled=26
scope.1.id=function:anonymous@7:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=11
scope.1.semanticHash=05a8e8375f6932b3
scope.1.lastMutatedAt=2026-06-24T20:10:10Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=survived
scope.1.lastMutationSites=4
scope.1.lastMutationKilled=2
scope.2.id=function:_outline_setter:6
scope.2.kind=function
scope.2.startLine=6
scope.2.endLine=12
scope.2.semanticHash=860102431601b34f
scope.3.id=function:_emit_ui_event:19
scope.3.kind=function
scope.3.startLine=19
scope.3.endLine=26
scope.3.semanticHash=351fb5ff63da3387
scope.3.lastMutatedAt=2026-06-24T20:10:10Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=survived
scope.3.lastMutationSites=3
scope.3.lastMutationKilled=2
scope.4.id=function:_emit_slot_animation:28
scope.4.kind=function
scope.4.startLine=28
scope.4.endLine=30
scope.4.semanticHash=07854e5fa8cb20f3
scope.4.lastMutatedAt=2026-06-24T20:10:10Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=1
scope.4.lastMutationKilled=1
scope.5.id=function:M.emit_global_reset_animation:48
scope.5.kind=function
scope.5.startLine=48
scope.5.endLine=50
scope.5.semanticHash=ebecadf320f03dc4
scope.5.lastMutatedAt=2026-06-24T20:10:10Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=1
scope.5.lastMutationKilled=1
]]
