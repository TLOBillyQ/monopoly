local nodes = require("src.ui.schema.item_atlas")
local number_utils = require("src.foundation.number")
local runtime_ui = require("src.ui.render.runtime_ui")

local item_atlas_view = {}

local PAGE_SIZE = 8

local _enlarged_overlay_nodes = {
  nodes.enlarged_card,
  nodes.close_hint_label,
  nodes.close_blank,
}

local function _resolve_runtime(deps)
  return (deps and deps.runtime) or runtime_ui
end

local function _set_enlarged_overlay_visible(ui, visible)
  if not ui.set_visible then
    return
  end
  for _, node_name in ipairs(_enlarged_overlay_nodes) do
    ui:set_visible(node_name, visible)
  end
end

local function _image_ref_key(refs, item_id)
  if item_id == nil then
    return nil
  end
  local key = tostring(item_id)
  return refs[key]
end

local function _refresh_card(ui, runtime, refs, node_name, item)
  if item then
    local image_key = _image_ref_key(refs, item.id)
    if image_key then
      local node = runtime.query_node(node_name)
      if node then
        runtime.set_node_texture_keep_size(node, image_key)
      end
    end
    if ui.set_visible then
      ui:set_visible(node_name, true)
    end
  elseif ui.set_visible then
    ui:set_visible(node_name, false)
  end
end

local function _refresh_page_arrows(ui, page_index, page_count)
  if not ui.set_visible then
    return
  end
  local has_multiple_pages = page_count > 1
  ui:set_visible(nodes.page_prev, has_multiple_pages and page_index > 1)
  ui:set_visible(nodes.page_next, has_multiple_pages and page_index < page_count)
end

function item_atlas_view.refresh_page(state, catalog, page_index, deps)
  local ui = assert(state.ui, "missing ui")
  local runtime = _resolve_runtime(deps)
  local refs = state.ui_refs and state.ui_refs.images or {}
  local offset = (page_index - 1) * PAGE_SIZE

  for slot = 1, PAGE_SIZE do
    local node_name = nodes.card_images[slot]
    if node_name then
      _refresh_card(ui, runtime, refs, node_name, catalog[offset + slot])
    end
  end

  _refresh_page_arrows(ui, page_index, number_utils.page_count(#catalog, PAGE_SIZE))
end

function item_atlas_view.show_enlarged(state, item_id, deps)
  local ui = assert(state.ui, "missing ui")
  local runtime = _resolve_runtime(deps)
  local refs = state.ui_refs and state.ui_refs.images or {}

  local image_key = _image_ref_key(refs, item_id)
  if image_key == nil then
    return
  end
  local node = runtime.query_node(nodes.enlarged_card)
  if node then
    runtime.set_node_texture_keep_size(node, image_key)
  end
  _set_enlarged_overlay_visible(ui, true)
end

function item_atlas_view.hide_enlarged(state)
  local ui = assert(state.ui, "missing ui")
  _set_enlarged_overlay_visible(ui, false)
end

return item_atlas_view
