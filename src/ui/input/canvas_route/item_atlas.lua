local nodes = require("src.ui.schema.item_atlas")
local append_intent_spec = require("src.ui.input.canvas_route.append_intent_spec")

local intents = {}

local _append = append_intent_spec.builder("item_atlas_action")

function intents.build(_state)
  local specs = {}
  _append(specs, nodes.close_button, "close")
  _append(specs, nodes.close_blank, "dismiss")
  _append(specs, nodes.page_prev, "prev")
  _append(specs, nodes.page_next, "next")
  for slot_index, name in ipairs(nodes.card_images) do
    _append(specs, name, { type = "select", slot_index = slot_index })
  end
  return specs
end

return intents

--[[ mutate4lua-manifest
version=2
projectHash=a65e1dbd887f9039
scope.0.id=chunk:src/ui/input/canvas_route/item_atlas.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=21
scope.0.semanticHash=328eb4c8b51fe9b5
scope.0.lastMutatedAt=2026-05-23T23:34:31Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=9
scope.0.lastMutationKilled=9
]]
