local nodes = require("src.ui.schema.skin")
local runtime_ui = require("src.ui.render.runtime_ui")

local skin_panel_view = {}

local function _resolve_runtime(deps)
  return (deps and deps.runtime) or runtime_ui
end

local function _skin_image_ref(refs, product_id)
  if product_id == nil then
    return nil
  end
  return refs[tostring(product_id)]
end

function skin_panel_view.refresh_slots(state, catalog, deps)
  local ui = assert(state.ui, "missing ui")
  local runtime = _resolve_runtime(deps)
  local image_refs = state.ui_refs and state.ui_refs.images or {}

  for slot = 1, 6 do
    local skin = catalog[slot]
    local card_name = nodes.card_images[slot]
    if card_name and skin then
      local image_key = _skin_image_ref(image_refs, skin.product_id)
      if image_key then
        local node = runtime.query_node(card_name)
        if node then
          runtime.set_node_texture_keep_size(node, image_key)
        end
      end
    end

    local price_icon = nodes.price_icons[slot]
    if price_icon and skin then
      local has_price = skin.price ~= nil and skin.currency ~= nil
      if ui.set_visible then
        ui:set_visible(price_icon, has_price)
      end
    end
  end
end

return skin_panel_view
