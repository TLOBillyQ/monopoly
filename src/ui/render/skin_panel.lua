local nodes = require("src.ui.schema.skin")
local panel_runtime = require("src.ui.render.panel_runtime")
local ui_controls = require("src.ui.render.support.ui_controls")

local skin_panel_view = {}

local _resolve_runtime = panel_runtime.resolve

local function _skin_image_ref(refs, product_id)
  if product_id == nil then
    return nil
  end
  return refs[tostring(product_id)]
end

local function _refresh_static_nodes(ui)
  ui_controls.set_controls_state(ui, nodes.static_visual_nodes, { visible = true, touch_enabled = false })
  ui_controls.set_control_state(ui, nodes.close_button, { visible = true, touch_enabled = true })
end

local function _slot_state(panel, skin)
  if not panel or not skin then
    return "empty"
  end
  local role_key = tostring(panel.role_id)
  local owned_map = panel.owned_by_role[role_key]
  local is_owned = owned_map and owned_map[skin.product_id] == true
  if not is_owned then
    return "locked"
  end
  local equipped_id = panel.selected_by_role[role_key]
  if equipped_id == skin.product_id then
    return "equipped"
  end
  return "owned"
end

local function _button_text_for_locked(skin)
  if skin.unlock == "gift" and skin.gift_name then
    return skin.gift_name
  end
  if skin.price ~= nil then
    return tostring(skin.price)
  end
  return ""
end

local function _button_props(skin, status)
  if status == "locked" then
    return _button_text_for_locked(skin), skin.unlock == "purchase"
  elseif status == "owned" then
    return "穿上", true
  elseif status == "equipped" then
    return "脱下", true
  elseif status == "empty" then
    return "", false
  end
  return nil, nil
end

local function _refresh_button(ui, slot, skin, status)
  local button_name = nodes.action_buttons[slot]
  if not button_name then
    return
  end
  local text, touch_enabled = _button_props(skin, status)
  local visible = skin ~= nil
  if text ~= nil and ui.set_button then
    ui:set_button(button_name, text)
  end
  if ui.set_visible then
    ui:set_visible(button_name, visible)
  end
  if touch_enabled ~= nil and ui.set_touch_enabled then
    ui:set_touch_enabled(button_name, touch_enabled)
  end
end

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
  else
    local node = runtime.query_node(card_name)
    if node then
      runtime.set_node_texture_keep_size(node, image_key)
    end
  end
end

local function _refresh_card_image(ui, runtime, image_refs, slot, skin)
  local card_name = nodes.card_images[slot]
  if not card_name then
    return
  end
  if skin then
    local product_id = skin.product_id
    local image_key = _skin_image_ref(image_refs, product_id)
    if image_key then
      _set_card_texture(runtime, card_name, image_key)
    end
  end
  if ui.set_visible then
    ui:set_visible(card_name, skin ~= nil)
  end
  if ui.set_touch_enabled then
    ui:set_touch_enabled(card_name, skin ~= nil)
  end
end

local function _refresh_price_icon(ui, slot, skin, status)
  local price_icon = nodes.price_icons[slot]
  if not price_icon or not ui.set_visible then
    return
  end
  local is_purchase = skin ~= nil and skin.unlock == "purchase"
  local has_price = is_purchase and skin.price ~= nil and skin.currency ~= nil
  local is_owned = status == "owned" or status == "equipped"
  ui:set_visible(price_icon, has_price and not is_owned)
  if ui.set_touch_enabled then
    ui:set_touch_enabled(price_icon, false)
  end
end

local PAGE_SIZE = #nodes.card_images

function skin_panel_view.refresh_slots(state, catalog, deps)
  local ui = assert(state.ui, "missing ui")
  local runtime = _resolve_runtime(state, deps)
  local image_refs = state.ui_refs and state.ui_refs.images or {}
  local panel = ui.skin_panel
  local page_index = (panel and panel.page_index) or 1
  local offset = (page_index - 1) * PAGE_SIZE

  _refresh_static_nodes(ui)

  for slot in ipairs(nodes.card_images) do
    local skin = catalog[offset + slot]
    local has_skin = skin ~= nil
    local status = _slot_state(panel, skin)
    _refresh_card_frame(ui, slot, has_skin)
    _refresh_card_image(ui, runtime, image_refs, slot, skin)
    _refresh_price_icon(ui, slot, skin, status)
    _refresh_button(ui, slot, skin, status)
    _refresh_card_outline_container(ui, slot, has_skin)
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
