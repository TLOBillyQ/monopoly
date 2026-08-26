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

local function _set_matched_textures(runtime, card_name, image_key)
  local ok_qn, matched_nodes = pcall(runtime.query_nodes, card_name)
  if ok_qn and type(matched_nodes) == "table" then
    for _, node in ipairs(matched_nodes) do
      runtime.set_node_texture_keep_size(node, image_key)
    end
  end
end

local function _set_card_texture(runtime, card_name, image_key)
  if type(runtime.query_nodes) == "function" then
    _set_matched_textures(runtime, card_name, image_key)
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
  local image = runtime_assets.image_for_skin_card(skin.product_id, runtime_assets.asset_context(state))
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

local function _refresh_price_icon(ui, slot, view)
  local price_icon = nodes.price_icons[slot]
  if not price_icon or not ui.set_visible then
    return
  end
  ui:set_visible(price_icon, view and view.price_icon_visible == true)
  if ui.set_touch_enabled then
    ui:set_touch_enabled(price_icon, false)
  end
end

function M.refresh_slot_visuals(state, ui, runtime, slot, view)
  local skin = view and view.skin or nil
  local has_skin = view and view.has_skin == true
  _refresh_card_frame(ui, slot, has_skin)
  _refresh_card_image(state, ui, runtime, slot, skin)
  _refresh_price_icon(ui, slot, view)
  _refresh_card_outline_container(ui, slot, has_skin)
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=f1f7d00b0540b7bc
scope.0.id=chunk:src/ui/render/widgets/skin_panel_cards.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=101
scope.0.semanticHash=090cde9277f0d618
scope.1.id=function:_refresh_card_frame
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=13
scope.1.semanticHash=7235e94acf4c0c7c
scope.2.id=function:_refresh_card_outline_container
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=26
scope.2.semanticHash=11d25e7bab9dd81d
scope.3.id=function:_set_matched_textures
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=35
scope.3.semanticHash=556742f37c52e5b5
scope.4.id=function:_set_card_texture
scope.4.kind=function
scope.4.startLine=37
scope.4.endLine=46
scope.4.semanticHash=f43dcc46b1e0b56c
scope.5.id=function:_skin_card_image_key
scope.5.kind=function
scope.5.startLine=48
scope.5.endLine=57
scope.5.semanticHash=36d0b335a746cd27
scope.6.id=function:_set_card_image_state
scope.6.kind=function
scope.6.startLine=59
scope.6.endLine=66
scope.6.semanticHash=6deb6598e6156063
scope.7.id=function:_refresh_card_image
scope.7.kind=function
scope.7.startLine=68
scope.7.endLine=78
scope.7.semanticHash=54d0356ad6628b2c
scope.8.id=function:_refresh_price_icon
scope.8.kind=function
scope.8.startLine=80
scope.8.endLine=89
scope.8.semanticHash=b9f8f4d1ef22e432
scope.9.id=function:M.refresh_slot_visuals
scope.9.kind=function
scope.9.startLine=91
scope.9.endLine=98
scope.9.semanticHash=cb90675ae093be8b
]]
