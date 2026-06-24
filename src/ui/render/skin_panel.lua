local nodes = require("src.ui.schema.skin")
local panel_runtime = require("src.ui.render.panel_runtime")
local ui_controls = require("src.ui.render.support.ui_controls")
local skin_buttons = require("src.ui.render.skin_panel_buttons")
local skin_cards = require("src.ui.render.skin_panel_cards")

local skin_panel_view = {}

local _resolve_runtime = panel_runtime.resolve

local function _refresh_static_nodes(ui)
  ui_controls.set_controls_state(ui, nodes.static_visual_nodes, { visible = true, touch_enabled = false })
  ui_controls.set_control_state(ui, nodes.close_button, { visible = true, touch_enabled = true })
end

local PAGE_SIZE = #nodes.card_images

function skin_panel_view.refresh_slots(state, catalog, deps)
  local ui = assert(state.ui, "missing ui")
  local runtime = _resolve_runtime(state, deps)
  local panel = ui.skin_panel
  local page_index = (panel and panel.page_index) or 1
  local offset = (page_index - 1) * PAGE_SIZE

  _refresh_static_nodes(ui)

  for slot in ipairs(nodes.card_images) do
    local skin = catalog[offset + slot]
    local status = skin_buttons.slot_state(panel, skin)
    skin_cards.refresh_slot_visuals(state, ui, runtime, slot, skin, status)
    skin_buttons.refresh_button(ui, slot, skin, status)
  end
end

return skin_panel_view

--[[ mutate4lua-manifest
version=2
projectHash=b9dde16bfb0331d4
scope.0.id=chunk:src/ui/render/skin_panel.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=175
scope.0.semanticHash=06e212d0167cf600
scope.0.lastMutatedAt=2026-05-30T07:39:43Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=35
scope.0.lastMutationKilled=35
scope.1.id=function:_skin_image_ref:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=14
scope.1.semanticHash=ca8941d4e4346d62
scope.1.lastMutatedAt=2026-05-30T07:39:43Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=2
scope.1.lastMutationKilled=2
scope.2.id=function:_refresh_static_nodes:16
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=19
scope.2.semanticHash=f35a6ee7f71d4ee0
scope.2.lastMutatedAt=2026-05-30T07:39:43Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=2
scope.2.lastMutationKilled=2
scope.3.id=function:_slot_state:21
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=36
scope.3.semanticHash=216d884868596c5c
scope.3.lastMutatedAt=2026-05-30T07:39:43Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=13
scope.3.lastMutationKilled=13
scope.4.id=function:_button_text_for_locked:38
scope.4.kind=function
scope.4.startLine=38
scope.4.endLine=46
scope.4.semanticHash=5d5b20a0f84e58d5
scope.4.lastMutatedAt=2026-05-30T07:39:43Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=6
scope.4.lastMutationKilled=6
scope.5.id=function:_button_props:48
scope.5.kind=function
scope.5.startLine=48
scope.5.endLine=59
scope.5.semanticHash=94545777be555219
scope.5.lastMutatedAt=2026-05-30T07:39:43Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=17
scope.5.lastMutationKilled=17
scope.6.id=function:_refresh_button:61
scope.6.kind=function
scope.6.startLine=61
scope.6.endLine=77
scope.6.semanticHash=6313383ecd12cabd
scope.6.lastMutatedAt=2026-05-30T07:39:43Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=10
scope.6.lastMutationKilled=10
scope.7.id=function:_refresh_card_frame:79
scope.7.kind=function
scope.7.startLine=79
scope.7.endLine=85
scope.7.semanticHash=64afc996508b2493
scope.7.lastMutatedAt=2026-05-30T07:39:43Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=2
scope.7.lastMutationKilled=2
scope.8.id=function:_refresh_card_outline_container:87
scope.8.kind=function
scope.8.startLine=87
scope.8.endLine=98
scope.8.semanticHash=afcb46ee7118d80b
scope.8.lastMutatedAt=2026-05-30T07:39:43Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=3
scope.8.lastMutationKilled=3
scope.9.id=function:_refresh_card_image:116
scope.9.kind=function
scope.9.startLine=116
scope.9.endLine=134
scope.9.semanticHash=131b6930d19abac7
scope.9.lastMutatedAt=2026-05-30T07:39:43Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=5
scope.9.lastMutationKilled=5
scope.10.id=function:_refresh_price_icon:136
scope.10.kind=function
scope.10.startLine=136
scope.10.endLine=148
scope.10.semanticHash=48379c293b146f7e
scope.10.lastMutatedAt=2026-05-30T07:39:43Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=18
scope.10.lastMutationKilled=18
]]
