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
  if skin.price ~= nil and skin.currency ~= nil then
    return tostring(skin.price) .. " " .. skin.currency
  end
  return ""
end

local function _button_props(skin, status)
  if status == "locked" then
    return _button_text_for_locked(skin), skin.unlock == "purchase"
  elseif status == "owned" then
    return "穿上", true
  elseif status == "equipped" then
    return "已穿戴", false
  end
  return nil, nil
end

local function _refresh_button(ui, slot, skin, status)
  local button_name = nodes.action_buttons[slot]
  if not button_name then
    return
  end
  local text, touch_enabled = _button_props(skin, status)
  if text ~= nil and ui.set_button then
    ui:set_button(button_name, text)
  end
  if touch_enabled ~= nil and ui.set_touch_enabled then
    ui:set_touch_enabled(button_name, touch_enabled)
  end
end

local function _refresh_outline(ui, slot, is_equipped)
  local outline_name = nodes.card_outlines[slot]
  if not outline_name then
    return
  end
  if ui.set_visible then
    ui:set_visible(outline_name, is_equipped)
  end
end

function skin_panel_view.refresh_slots(state, catalog, deps)
  local ui = assert(state.ui, "missing ui")
  local runtime = _resolve_runtime(deps)
  local image_refs = state.ui_refs and state.ui_refs.images or {}
  local panel = ui.skin_panel

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

    local status = _slot_state(panel, skin)
    if skin then
      _refresh_button(ui, slot, skin, status)
    end
    _refresh_outline(ui, slot, status == "equipped")
  end
end

return skin_panel_view
