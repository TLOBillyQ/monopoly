local nodes = require("src.ui.schema.skin")
local panel_runtime = require("src.ui.render.support.panel_runtime")
local ui_controls = require("src.ui.render.support.ui_controls")
local cosmetics_port = require("src.ui.seams.cosmetics").build()
local transaction = cosmetics_port.transaction
local skin_buttons = require("src.ui.render.widgets.skin_panel_buttons")
local skin_cards = require("src.ui.render.widgets.skin_panel_cards")

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
version=4
projectHash=1e7541ef5385aa20
scope.0.id=chunk:src/ui/render/widgets/skin_panel.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=33
scope.0.semanticHash=03ba42b6b1569365
scope.1.id=function:_refresh_static_nodes
scope.1.kind=function
scope.1.startLine=13
scope.1.endLine=16
scope.1.semanticHash=35d94dbc224ce8b7
scope.2.id=function:skin_panel_view.refresh_slots
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=30
scope.2.semanticHash=bedb95712fcee30c
]]
