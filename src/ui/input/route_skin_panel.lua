local nodes = require("src.ui.schema.skin")
local append_intent_spec = require("src.ui.input.route_specs")

local intents = {}

local INTENT_TYPE = "skin_panel_action"
local _append = append_intent_spec.builder(INTENT_TYPE)

local function _append_action_button(specs, name, slot_index)
  if not name then
    return
  end
  specs[#specs + 1] = {
    name = name,
    build_intent = function()
      return { type = INTENT_TYPE, action = { type = "activate_slot", slot_index = slot_index } }
    end,
  }
end

function intents.build(state)
  local specs = {}
  _append(specs, nodes.close_button, "close")
  for slot_index, name in ipairs(nodes.action_buttons) do
    _append_action_button(specs, name, slot_index)
  end
  for slot_index, name in ipairs(nodes.card_images) do
    _append(specs, name, { type = "equip", slot_index = slot_index })
  end
  return specs
end

return intents

--[[ mutate4lua-manifest
version=2
projectHash=f70ca5b6f8cefe36
scope.0.id=chunk:src/ui/input/route_skin_panel.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=34
scope.0.semanticHash=1137e29f60325259
scope.1.id=function:anonymous@15:15
scope.1.kind=function
scope.1.startLine=15
scope.1.endLine=17
scope.1.semanticHash=5aea64757c128480
scope.2.id=function:_append_action_button:9
scope.2.kind=function
scope.2.startLine=9
scope.2.endLine=19
scope.2.semanticHash=6d23c00f726899ad
]]
