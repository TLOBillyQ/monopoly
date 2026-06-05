local nodes = require("src.ui.schema.item_atlas")
local append_intent_spec = require("src.ui.input.route_specs")

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
projectHash=944c3164b08eabf8
scope.0.id=chunk:src/ui/input/route_item_atlas.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=21
scope.0.semanticHash=6589b31ca47cadca
]]
