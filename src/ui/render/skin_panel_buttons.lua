local nodes = require("src.ui.schema.skin")

local M = {}

local function _button_text_for_locked(skin)
  if skin.unlock == "gift" and skin.gift_name then
    return skin.gift_name
  end
  if skin.price ~= nil then
    return tostring(skin.price)
  end
  return ""
end

local BUTTON_PROPS = {
  owned = { text = "穿上", touch_enabled = true },
  equipped = { text = "脱下", touch_enabled = true },
  empty = { text = "", touch_enabled = false },
}

local function _button_props(skin, status)
  if status == "locked" then
    return _button_text_for_locked(skin), skin.unlock == "purchase"
  end
  local props = BUTTON_PROPS[status]
  if props ~= nil then
    return props.text, props.touch_enabled
  end
  return nil, nil
end

local function _set_optional_ui_value(ui, method_name, node_name, value)
  if value == nil then
    return
  end
  local setter = ui[method_name]
  if setter then
    setter(ui, node_name, value)
  end
end

function M.slot_state(panel, skin)
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

function M.refresh_button(ui, slot, skin, status)
  local button_name = nodes.action_buttons[slot]
  if not button_name then
    return
  end
  local text, touch_enabled = _button_props(skin, status)
  local visible = skin ~= nil
  _set_optional_ui_value(ui, "set_button", button_name, text)
  _set_optional_ui_value(ui, "set_visible", button_name, visible)
  _set_optional_ui_value(ui, "set_touch_enabled", button_name, touch_enabled)
end

return M
