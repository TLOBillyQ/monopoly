local nodes = require("src.ui.schema.skin")
local append_intent_spec = require("src.ui.input.canvas_route.append_intent_spec")

local intents = {}

local INTENT_TYPE = "skin_panel_action"
local _append = append_intent_spec.builder(INTENT_TYPE)

-- Lazily resolve the coord panel so this input-layer route can query live
-- equipped state without a load-time require cycle (coord registers the routes).
local _coord_skin_panel
local function _is_slot_equipped(state, slot_index)
  _coord_skin_panel = _coord_skin_panel or require("src.ui.coord.skin_panel")
  return _coord_skin_panel.is_slot_equipped(state, slot_index)
end

-- An equipped slot's action button is rendered as "脱下"; clicking it must
-- unequip. build() runs once at canvas-bind time, so the equip/unequip decision
-- is deferred into build_intent (per click) where it reads the live panel state.
local function _append_action_button(specs, name, slot_index, state)
  if not name then
    return
  end
  specs[#specs + 1] = {
    name = name,
    build_intent = function()
      local action_type = _is_slot_equipped(state, slot_index) and "unequip" or "equip"
      return { type = INTENT_TYPE, action = { type = action_type, slot_index = slot_index } }
    end,
  }
end

function intents.build(state)
  local specs = {}
  _append(specs, nodes.close_button, "close")
  for slot_index, name in ipairs(nodes.action_buttons) do
    _append_action_button(specs, name, slot_index, state)
  end
  for slot_index, name in ipairs(nodes.card_images) do
    _append(specs, name, { type = "equip", slot_index = slot_index })
  end
  return specs
end

return intents

--[[ mutate4lua-manifest
version=2
projectHash=a0e9f01277ad663e
scope.0.id=chunk:src/ui/input/canvas_route/skin_panel.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=46
scope.0.semanticHash=82db7aaa0d527699
scope.0.lastMutatedAt=2026-05-31T03:12:01Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=5
scope.0.lastMutationKilled=5
scope.1.id=function:_is_slot_equipped:12
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=15
scope.1.semanticHash=73ce48eb8562e8cf
scope.1.lastMutatedAt=2026-05-31T03:12:01Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=3
scope.1.lastMutationKilled=3
scope.2.id=function:anonymous@26:26
scope.2.kind=function
scope.2.startLine=26
scope.2.endLine=29
scope.2.semanticHash=0f6bd16001706ea2
scope.2.lastMutatedAt=2026-05-31T03:12:01Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=5
scope.2.lastMutationKilled=5
scope.3.id=function:_append_action_button:20
scope.3.kind=function
scope.3.startLine=20
scope.3.endLine=31
scope.3.semanticHash=52d5e5fe845b7a56
scope.3.lastMutatedAt=2026-05-31T03:12:01Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=3
scope.3.lastMutationKilled=3
]]
