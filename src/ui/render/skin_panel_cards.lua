local nodes = require("src.ui.schema.skin")
local runtime_assets = require("src.config.runtime_assets")
local ui_controls = require("src.ui.render.support.ui_controls")

local M = {}

local function _refresh_card_frame(ui, slot, visible)
  local frame_name = nodes.card_frames[slot]
  if not frame_name then
    return
  end
  ui_controls.set_control_state(ui, frame_name, { visible = visible, touch_enabled = false })
end

local function _refresh_card_outline_container(ui, slot, visible)
  local outline_name = nodes.card_outlines[slot]
  if not outline_name then
    return
  end
  if ui.set_visible then
    ui:set_visible(outline_name, visible)
  end
  if ui.set_touch_enabled then
    ui:set_touch_enabled(outline_name, false)
  end
end

local function _set_card_texture(runtime, card_name, image_key)
  if type(runtime.query_nodes) == "function" then
    local ok_qn, matched_nodes = pcall(runtime.query_nodes, card_name)
    if ok_qn and type(matched_nodes) == "table" then
      for _, node in ipairs(matched_nodes) do
        runtime.set_node_texture_keep_size(node, image_key)
      end
    end
  elseif type(runtime.query_node) == "function" then
    local node = runtime.query_node(card_name)
    if node then
      runtime.set_node_texture_keep_size(node, image_key)
    end
  end
end

local function _skin_card_image_key(state, skin)
  if skin == nil then
    return nil
  end
  local image = runtime_assets.image_for_skin_card(skin.product_id, {
    refs = state.ui_refs,
  })
  if image.ok == true then
    return image.image_key
  end
  return nil
end

local function _set_card_image_state(ui, card_name, visible)
  if ui.set_visible then
    ui:set_visible(card_name, visible)
  end
  if ui.set_touch_enabled then
    ui:set_touch_enabled(card_name, visible)
  end
end

local function _refresh_card_image(state, ui, runtime, slot, skin)
  local card_name = nodes.card_images[slot]
  if not card_name then
    return
  end
  local image_key = _skin_card_image_key(state, skin)
  if image_key ~= nil then
    _set_card_texture(runtime, card_name, image_key)
  end
  _set_card_image_state(ui, card_name, skin ~= nil)
end

local function _price_icon_visible(skin, status)
  local is_purchase = skin ~= nil and skin.unlock == "purchase"
  local has_price = is_purchase and skin.price ~= nil and skin.currency ~= nil
  local is_owned = status == "owned" or status == "equipped"
  return has_price and not is_owned
end

local function _refresh_price_icon(ui, slot, skin, status)
  local price_icon = nodes.price_icons[slot]
  if not price_icon or not ui.set_visible then
    return
  end
  ui:set_visible(price_icon, _price_icon_visible(skin, status))
  if ui.set_touch_enabled then
    ui:set_touch_enabled(price_icon, false)
  end
end

function M.refresh_slot_visuals(state, ui, runtime, slot, skin, status)
  local has_skin = skin ~= nil
  _refresh_card_frame(ui, slot, has_skin)
  _refresh_card_image(state, ui, runtime, slot, skin)
  _refresh_price_icon(ui, slot, skin, status)
  _refresh_card_outline_container(ui, slot, has_skin)
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=0b04d33aabe7144b
scope.0.id=chunk:src/ui/render/skin_panel_cards.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=105
scope.0.semanticHash=5fe4279a19a51098
scope.0.lastMutatedAt=2026-06-24T20:14:58Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=18
scope.0.lastMutationKilled=18
scope.1.id=function:_refresh_card_frame:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=13
scope.1.semanticHash=64afc996508b2493
scope.1.lastMutatedAt=2026-06-24T20:14:58Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=2
scope.1.lastMutationKilled=2
scope.2.id=function:_refresh_card_outline_container:15
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=26
scope.2.semanticHash=afcb46ee7118d80b
scope.2.lastMutatedAt=2026-06-24T20:14:58Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=3
scope.2.lastMutationKilled=3
scope.3.id=function:_skin_card_image_key:44
scope.3.kind=function
scope.3.startLine=44
scope.3.endLine=55
scope.3.semanticHash=3807f7fca57e4edc
scope.3.lastMutatedAt=2026-06-24T20:14:58Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=4
scope.3.lastMutationKilled=4
scope.4.id=function:_set_card_image_state:57
scope.4.kind=function
scope.4.startLine=57
scope.4.endLine=64
scope.4.semanticHash=7c8ecf4a1f9f627f
scope.4.lastMutatedAt=2026-06-24T20:14:58Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=2
scope.4.lastMutationKilled=2
scope.5.id=function:_refresh_card_image:66
scope.5.kind=function
scope.5.startLine=66
scope.5.endLine=76
scope.5.semanticHash=817d977c192938df
scope.5.lastMutatedAt=2026-06-24T20:14:58Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=5
scope.5.lastMutationKilled=5
scope.6.id=function:_price_icon_visible:78
scope.6.kind=function
scope.6.startLine=78
scope.6.endLine=83
scope.6.semanticHash=8bc90c7c19a18fec
scope.6.lastMutatedAt=2026-06-24T20:14:58Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=15
scope.6.lastMutationKilled=15
scope.7.id=function:_refresh_price_icon:85
scope.7.kind=function
scope.7.startLine=85
scope.7.endLine=94
scope.7.semanticHash=d5fb847b6bfbcf8c
scope.7.lastMutatedAt=2026-06-24T20:14:58Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=5
scope.7.lastMutationKilled=5
scope.8.id=function:M.refresh_slot_visuals:96
scope.8.kind=function
scope.8.startLine=96
scope.8.endLine=102
scope.8.semanticHash=5671a3f7af918638
scope.8.lastMutatedAt=2026-06-24T20:14:58Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=5
scope.8.lastMutationKilled=5
]]
