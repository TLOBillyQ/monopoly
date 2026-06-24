local nodes = require("src.ui.schema.item_atlas")
local number_utils = require("src.foundation.number")
local panel_runtime = require("src.ui.render.panel_runtime")
local runtime_assets = require("src.config.runtime_assets")

local item_atlas_view = {}

local PAGE_SIZE = #nodes.card_images

local _enlarged_overlay_nodes = {
  nodes.enlarged_card,
  nodes.close_hint_label,
  nodes.close_blank,
}

local _resolve_runtime = panel_runtime.resolve

local function _set_enlarged_overlay_visible(ui, visible)
  for _, node_name in ipairs(_enlarged_overlay_nodes) do
    if ui.set_visible then
      ui:set_visible(node_name, visible)
    end
  end
  if ui.set_touch_enabled then
    ui:set_touch_enabled(nodes.close_blank, visible == true)
  end
end

local function _item_image_key(refs, item_id)
  local image = runtime_assets.image_for_item(item_id, { refs = refs })
  return image.ok == true and image.image_key or nil
end

local function _apply_card_texture(runtime, refs, node_name, item)
  local image_key = _item_image_key(refs, item.id)
  if not image_key then
    return
  end
  if type(runtime.query_nodes) == "function" then
    local matched_nodes = runtime.query_nodes(node_name)
    for _, node in ipairs(matched_nodes) do
      runtime.set_node_texture_keep_size(node, image_key)
    end
  else
    local node = runtime.query_node(node_name)
    if node then
      runtime.set_node_texture_keep_size(node, image_key)
    end
  end
end

local function _set_card_visibility(ui, node_name, visible)
  if ui.set_visible then
    ui:set_visible(node_name, visible)
  end
end

local function _refresh_card(ui, runtime, refs, node_name, item)
  local has_item = item ~= nil
  if item then
    _apply_card_texture(runtime, refs, node_name, item)
    _set_card_visibility(ui, node_name, true)
  else
    _set_card_visibility(ui, node_name, false)
  end
  if ui.set_touch_enabled then
    ui:set_touch_enabled(node_name, has_item)
  end
end

local function _refresh_page_arrows(ui, page_index, page_count)
  local has_multiple_pages = page_count > 1
  local prev_visible = has_multiple_pages and page_index > 1
  local next_visible = has_multiple_pages and page_index < page_count
  if ui.set_visible then
    ui:set_visible(nodes.page_prev, prev_visible)
    ui:set_visible(nodes.page_next, next_visible)
  end
  if ui.set_touch_enabled then
    ui:set_touch_enabled(nodes.page_prev, prev_visible)
    ui:set_touch_enabled(nodes.page_next, next_visible)
  end
end

function item_atlas_view.refresh_page(state, catalog, page_index, deps)
  local ui = assert(state.ui, "missing ui")
  local runtime = _resolve_runtime(state, deps)
  local refs = state.ui_refs or {}
  local offset = (page_index - 1) * PAGE_SIZE

  for slot, node_name in ipairs(nodes.card_images) do
    _refresh_card(ui, runtime, refs, node_name, catalog[offset + slot])
  end

  _refresh_page_arrows(ui, page_index, number_utils.page_count(#catalog, PAGE_SIZE))
end

function item_atlas_view.show_enlarged(state, item_id, deps)
  local ui = assert(state.ui, "missing ui")
  local runtime = _resolve_runtime(state, deps)
  local refs = state.ui_refs or {}

  local image_key = _item_image_key(refs, item_id)
  if image_key == nil then
    return
  end
  if type(runtime.query_nodes) == "function" then
    local matched_nodes = runtime.query_nodes(nodes.enlarged_card)
    for _, node in ipairs(matched_nodes) do
      runtime.set_node_texture_keep_size(node, image_key)
    end
  else
    local node = runtime.query_node(nodes.enlarged_card)
    if node then
      runtime.set_node_texture_keep_size(node, image_key)
    end
  end
  _set_enlarged_overlay_visible(ui, true)
end

function item_atlas_view.hide_enlarged(state)
  local ui = assert(state.ui, "missing ui")
  _set_enlarged_overlay_visible(ui, false)
end

return item_atlas_view

--[[ mutate4lua-manifest
version=2
projectHash=c3593c86af00b345
scope.0.id=chunk:src/ui/render/item_atlas.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=129
scope.0.semanticHash=245908ac98830be6
scope.0.lastMutatedAt=2026-06-01T12:41:06Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=41
scope.0.lastMutationKilled=41
scope.1.id=function:_image_ref_key:28
scope.1.kind=function
scope.1.startLine=28
scope.1.endLine=34
scope.1.semanticHash=207fe5b70dc77502
scope.1.lastMutatedAt=2026-06-01T12:41:06Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=2
scope.1.lastMutationKilled=2
scope.2.id=function:_set_card_visibility:54
scope.2.kind=function
scope.2.startLine=54
scope.2.endLine=58
scope.2.semanticHash=578d71adb368abe2
scope.2.lastMutatedAt=2026-06-01T12:41:06Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=1
scope.2.lastMutationKilled=1
scope.3.id=function:_refresh_card:60
scope.3.kind=function
scope.3.startLine=60
scope.3.endLine=71
scope.3.semanticHash=86f26eb0605b244a
scope.3.lastMutatedAt=2026-06-01T12:41:06Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=5
scope.3.lastMutationKilled=5
scope.4.id=function:_refresh_page_arrows:73
scope.4.kind=function
scope.4.startLine=73
scope.4.endLine=85
scope.4.semanticHash=2a9381c8568b718a
scope.4.lastMutatedAt=2026-06-01T12:41:06Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=11
scope.4.lastMutationKilled=11
scope.5.id=function:item_atlas_view.hide_enlarged:123
scope.5.kind=function
scope.5.startLine=123
scope.5.endLine=126
scope.5.semanticHash=f995e0c09d178218
scope.5.lastMutatedAt=2026-06-01T12:41:06Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=2
scope.5.lastMutationKilled=2
]]
