local nodes = require("src.ui.schema.skin")
local panel_runtime = require("src.ui.render.panel_runtime")
local ui_controls = require("src.ui.render.support.ui_controls")
local transaction = require("src.app.cosmetics.transaction")
local skin_buttons = require("src.ui.render.skin_panel_buttons")
local skin_cards = require("src.ui.render.skin_panel_cards")

local skin_panel_view = {}

local _resolve_runtime = panel_runtime.resolve

local function _refresh_static_nodes(ui)
  ui_controls.set_controls_state(ui, nodes.static_visual_nodes, { visible = true, touch_enabled = false })
  ui_controls.set_control_state(ui, nodes.close_button, { visible = true, touch_enabled = true })
end

function skin_panel_view.refresh_slots(state, catalog, deps)
  local ui = assert(state.ui, "missing ui")
  local runtime = _resolve_runtime(state, deps)
  local slot_views = transaction.slot_view_models(state, catalog)

  _refresh_static_nodes(ui)

  for slot in ipairs(nodes.card_images) do
    local view = slot_views[slot]
    skin_cards.refresh_slot_visuals(state, ui, runtime, slot, view)
    skin_buttons.refresh_button(ui, slot, view)
  end
end

return skin_panel_view

--[[ mutate4lua-manifest
version=2
projectHash=a485d1e97257dba1
scope.0.id=chunk:src/ui/render/skin_panel.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=36
scope.0.semanticHash=3e3e9df60229a1b1
scope.0.lastMutatedAt=2026-06-24T20:14:25Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=19
scope.0.lastMutationKilled=19
scope.1.id=function:_refresh_static_nodes:11
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=14
scope.1.semanticHash=f35a6ee7f71d4ee0
scope.1.lastMutatedAt=2026-06-24T20:14:25Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=2
scope.1.lastMutationKilled=2
]]
