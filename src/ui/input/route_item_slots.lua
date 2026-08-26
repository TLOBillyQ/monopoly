-- 道具槽点击路由：只报事实——谁点了第几个槽——不做任何「在不在道具阶段」的判断。
-- 裁定与用户反馈全部归 turn 层（src.turn.actions.item_slot_click）。
-- 这里唯一保留的本地门是遮挡：弹层盖住时点击属于误触，静默；这是纯展示语义，
-- turn 层看不见谁的屏幕上有弹层。
local nodes = require("src.ui.schema.permanent")
local slot_overlay = require("src.ui.input.item_slot_overlay")
local local_actor_resolver = require("src.ui.seams.local_actor_resolver")

local intents = {}

local function _slot_intent_builder(state, index)
  return function(data)
    local actor_role_id = local_actor_resolver.resolve_from_event(state, data)
    if slot_overlay.blocks_click(state, actor_role_id) then
      return nil
    end
    return { type = "item_slot_click", slot_index = index, actor_role_id = actor_role_id }
  end
end

local function _screen_nodes(state, field, fallback)
  return (state.ui and state.ui[field]) or fallback or {}
end

function intents.build(state)
  local specs = {}
  local item_slots = _screen_nodes(state, "item_slots", nodes.item_slots)
  for index, node_name in ipairs(item_slots) do
    specs[#specs + 1] = { name = node_name, build_intent = _slot_intent_builder(state, index) }
  end
  return specs
end

return intents

--[[ mutate4lua-manifest
version=4
projectHash=b0d2ec92cc82cb99
scope.0.id=chunk:src/ui/input/route_item_slots.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=35
scope.0.semanticHash=31bcec05532560d5
scope.1.id=function:_slot_intent_builder
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=19
scope.1.semanticHash=862e7133f78cf1d7
scope.2.id=function:<anonymous>
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=18
scope.2.semanticHash=e471a9766b2996a5
scope.3.id=function:_screen_nodes
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=23
scope.3.semanticHash=6011834c2cba6e03
scope.4.id=function:intents.build
scope.4.kind=function
scope.4.startLine=25
scope.4.endLine=32
scope.4.semanticHash=395482bd2f9e3804
]]
