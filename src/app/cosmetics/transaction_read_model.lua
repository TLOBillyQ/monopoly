local transaction_context = require("src.app.cosmetics.transaction_context")
local number_utils = require("src.foundation.number")

local read_model = {}

local PAGE_SIZE = 6

function read_model.role_key(role_id)
  if role_id == nil then
    return nil
  end
  return tostring(role_id)
end

function read_model.slot_index(panel, slot_index)
  local slot = number_utils.to_integer(slot_index) or 1
  return ((panel and panel.page_index or 1) - 1) * PAGE_SIZE + slot
end

function read_model.skin_at(panel, slot_index, catalog)
  local effective_catalog = catalog or transaction_context.catalog()
  return effective_catalog[read_model.slot_index(panel, slot_index)]
end

function read_model.skin_by_product(product_id)
  for _, skin in ipairs(transaction_context.catalog()) do
    if skin.product_id == product_id then
      return skin
    end
  end
  return nil
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

local BUTTON_PROPS = {
  owned = { text = "穿上", touch_enabled = true },
  equipped = { text = "脱下", touch_enabled = true },
  empty = { text = "", touch_enabled = false },
}

local function _slot_status(panel, role_id, skin)
  if skin == nil then
    return "empty"
  end
  local key = read_model.role_key(role_id)
  local owned_map = key and panel and panel.owned_by_role and panel.owned_by_role[key] or nil
  if owned_map == nil or owned_map[skin.product_id] ~= true then
    return "locked"
  end
  local equipped_id = panel and panel.selected_by_role and panel.selected_by_role[key] or nil
  if equipped_id == skin.product_id then
    return "equipped"
  end
  return "owned"
end

local function _button_props(skin, status)
  if status == "locked" and skin ~= nil then
    return _button_text_for_locked(skin), skin.unlock == "purchase"
  end
  local props = BUTTON_PROPS[status] or BUTTON_PROPS.empty
  return props.text, props.touch_enabled
end

local function _price_icon_visible(skin, status)
  local is_purchase = skin ~= nil and skin.unlock == "purchase"
  local has_price = is_purchase and skin.price ~= nil and skin.currency ~= nil
  local is_owned = status == "owned" or status == "equipped"
  return has_price and not is_owned
end

function read_model.slot_view_model(panel, role_id, slot_index, catalog)
  local skin = read_model.skin_at(panel, slot_index, catalog)
  local status = _slot_status(panel, role_id or (panel and panel.role_id), skin)
  local button_text, button_touch_enabled = _button_props(skin, status)
  return {
    slot_index = number_utils.to_integer(slot_index) or 1,
    catalog_index = read_model.slot_index(panel, slot_index),
    skin = skin,
    has_skin = skin ~= nil,
    product_id = skin and skin.product_id or nil,
    name = skin and skin.name or nil,
    unlock = skin and skin.unlock or nil,
    status = status,
    button_text = button_text,
    button_touch_enabled = button_touch_enabled,
    price_icon_visible = _price_icon_visible(skin, status),
  }
end

function read_model.slot_view_models(panel, role_id, catalog)
  local views = {}
  for slot_index = 1, PAGE_SIZE do
    views[slot_index] = read_model.slot_view_model(panel, role_id, slot_index, catalog)
  end
  return views
end

function read_model.clamp_page(page_index)
  return number_utils.clamp(page_index, 1, number_utils.page_count(#transaction_context.catalog(), PAGE_SIZE))
end

return read_model

--[[ mutate4lua-manifest
version=2
projectHash=ff16b4022ecf14af
scope.0.id=chunk:src/app/cosmetics/transaction_read_model.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=113
scope.0.semanticHash=542b6d12f78b9fa6
scope.1.id=function:read_model.role_key:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=13
scope.1.semanticHash=249d29416296e237
scope.2.id=function:read_model.slot_index:15
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=18
scope.2.semanticHash=e83080142250ddc1
scope.3.id=function:read_model.skin_at:20
scope.3.kind=function
scope.3.startLine=20
scope.3.endLine=23
scope.3.semanticHash=83b863755504c219
scope.4.id=function:_button_text_for_locked:34
scope.4.kind=function
scope.4.startLine=34
scope.4.endLine=42
scope.4.semanticHash=5d5b20a0f84e58d5
scope.5.id=function:_slot_status:50
scope.5.kind=function
scope.5.startLine=50
scope.5.endLine=64
scope.5.semanticHash=984cae81cb57a0fd
scope.6.id=function:_button_props:66
scope.6.kind=function
scope.6.startLine=66
scope.6.endLine=72
scope.6.semanticHash=f682a8fc9bebdb13
scope.7.id=function:_price_icon_visible:74
scope.7.kind=function
scope.7.startLine=74
scope.7.endLine=79
scope.7.semanticHash=8bc90c7c19a18fec
scope.8.id=function:read_model.slot_view_model:81
scope.8.kind=function
scope.8.startLine=81
scope.8.endLine=98
scope.8.semanticHash=f947dc13631451a6
scope.9.id=function:read_model.clamp_page:108
scope.9.kind=function
scope.9.startLine=108
scope.9.endLine=110
scope.9.semanticHash=07e7e460f147cac3
]]
