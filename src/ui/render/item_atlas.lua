local nodes = require("src.ui.schema.item_atlas")
local runtime_ui = require("src.ui.render.runtime_ui")

local item_atlas_view = {}

local PAGE_SIZE = 8

local function _resolve_runtime(deps)
  return (deps and deps.runtime) or runtime_ui
end

local function _image_ref_key(refs, item_id)
  if item_id == nil then
    return nil
  end
  local key = tostring(item_id)
  return refs[key]
end

local function _page_count(catalog)
  return math.max(1, math.floor((#catalog + PAGE_SIZE - 1) / PAGE_SIZE))
end

function item_atlas_view.refresh_page(state, catalog, page_index, deps)
  local ui = assert(state.ui, "missing ui")
  local runtime = _resolve_runtime(deps)
  local refs = state.ui_refs and state.ui_refs.images or {}
  local offset = (page_index - 1) * PAGE_SIZE

  for slot = 1, PAGE_SIZE do
    local node_name = nodes.card_images[slot]
    if node_name then
      local item = catalog[offset + slot]
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
      else
        if ui.set_visible then
          ui:set_visible(node_name, false)
        end
      end
    end
  end

  if ui.set_label then
    ui:set_label(nodes.title_label, tostring(page_index) .. "/" .. tostring(_page_count(catalog)))
  end
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
  if ui.set_visible then
    ui:set_visible(nodes.enlarged_card, true)
    ui:set_visible(nodes.close_hint_label, true)
  end
end

function item_atlas_view.hide_enlarged(state)
  local ui = assert(state.ui, "missing ui")
  if ui.set_visible then
    ui:set_visible(nodes.enlarged_card, false)
    ui:set_visible(nodes.close_hint_label, false)
  end
end

return item_atlas_view
