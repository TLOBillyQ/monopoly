local runtime = require("src.ui.render.support.runtime_ui")
local ui_events = require("src.ui.coord.ui_events")

local M = {}

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

return M

--[[ mutate4lua-manifest
version=4
projectHash=2e1944f56ad2d1a0
scope.0.id=chunk:src/ui/coord/item_slots_events.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=40
scope.0.semanticHash=87f5a2643b1a9266
scope.1.id=function:_emit_ui_event
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=15
scope.1.semanticHash=baba6ab117d60940
scope.2.id=function:_emit_slot_animation
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=19
scope.2.semanticHash=4bab5538716f84dd
scope.3.id=function:M.emit_global_reset_animation
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=23
scope.3.semanticHash=b1f16ed07f03ac7a
scope.4.id=function:M.emit_pickable_slot_animation
scope.4.kind=function
scope.4.startLine=25
scope.4.endLine=37
scope.4.semanticHash=2e7533242dce1ec3
]]
