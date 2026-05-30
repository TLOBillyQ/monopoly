local nodes = require("src.ui.schema.skin")
local append_intent_spec = require("src.ui.input.canvas_route.append_intent_spec")

local intents = {}

local _append = append_intent_spec.builder("skin_panel_action")

function intents.build(_state)
  local specs = {}
  _append(specs, nodes.close_button, "close")
  for slot_index, name in ipairs(nodes.action_buttons) do
    _append(specs, name, { type = "equip", slot_index = slot_index })
  end
  for slot_index, name in ipairs(nodes.card_images) do
    _append(specs, name, { type = "equip", slot_index = slot_index })
  end
  return specs
end

return intents

--[[ mutate4lua-manifest
version=2
projectHash=18125de48b7e6ac6
scope.0.id=chunk:src/ui/input/canvas_route/skin_panel.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=21
scope.0.semanticHash=d2fb29d1e396362f
scope.0.lastMutatedAt=2026-05-23T23:34:39Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=8
scope.0.lastMutationKilled=8
]]
