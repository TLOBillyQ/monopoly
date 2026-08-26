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

local function _owned_map_for_role(panel, key)
  return key and panel and panel.owned_by_role and panel.owned_by_role[key] or nil
end

local function _equipped_id_for_role(panel, key)
  return panel and panel.selected_by_role and panel.selected_by_role[key] or nil
end

local function _slot_status(panel, role_id, skin)
  if skin == nil then
    return "empty"
  end
  local key = read_model.role_key(role_id)
  local owned_map = _owned_map_for_role(panel, key)
  if owned_map == nil or owned_map[skin.product_id] ~= true then
    return "locked"
  end
  if _equipped_id_for_role(panel, key) == skin.product_id then
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

local function _has_price(skin)
  return skin ~= nil and skin.unlock == "purchase" and skin.price ~= nil and skin.currency ~= nil
end

local function _is_owned_status(status)
  return status == "owned" or status == "equipped"
end

local function _price_icon_visible(skin, status)
  return _has_price(skin) and not _is_owned_status(status)
end

local function _skin_field(skin, key)
  return skin and skin[key] or nil
end

local function _skin_fields(skin)
  return {
    has_skin = skin ~= nil,
    product_id = _skin_field(skin, "product_id"),
    name = _skin_field(skin, "name"),
    unlock = _skin_field(skin, "unlock"),
  }
end

function read_model.slot_view_model(panel, role_id, slot_index, catalog)
  local skin = read_model.skin_at(panel, slot_index, catalog)
  local status = _slot_status(panel, role_id or (panel and panel.role_id), skin)
  local button_text, button_touch_enabled = _button_props(skin, status)
  local fields = _skin_fields(skin)
  return {
    slot_index = number_utils.to_integer(slot_index) or 1,
    catalog_index = read_model.slot_index(panel, slot_index),
    skin = skin,
    has_skin = fields.has_skin,
    product_id = fields.product_id,
    name = fields.name,
    unlock = fields.unlock,
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
version=4
projectHash=7db3fc6e8ba2d8f7
scope.0.id=chunk:src/app/cosmetics/transaction_read_model.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=139
scope.0.semanticHash=83fb71b16426c4b2
scope.1.id=function:read_model.role_key
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=13
scope.1.semanticHash=4d0700d0f9defcb3
scope.2.id=function:read_model.slot_index
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=18
scope.2.semanticHash=f6a9de87d125efd0
scope.3.id=function:read_model.skin_at
scope.3.kind=function
scope.3.startLine=20
scope.3.endLine=23
scope.3.semanticHash=7bf7717743911074
scope.4.id=function:read_model.skin_by_product
scope.4.kind=function
scope.4.startLine=25
scope.4.endLine=32
scope.4.semanticHash=77c8d4077854ec81
scope.5.id=function:_button_text_for_locked
scope.5.kind=function
scope.5.startLine=34
scope.5.endLine=42
scope.5.semanticHash=96a4a6d0526efce7
scope.6.id=function:_owned_map_for_role
scope.6.kind=function
scope.6.startLine=50
scope.6.endLine=52
scope.6.semanticHash=0064648672ebc0ef
scope.7.id=function:_equipped_id_for_role
scope.7.kind=function
scope.7.startLine=54
scope.7.endLine=56
scope.7.semanticHash=bafa57000621798c
scope.8.id=function:_slot_status
scope.8.kind=function
scope.8.startLine=58
scope.8.endLine=71
scope.8.semanticHash=b820bb2e7d7443c1
scope.9.id=function:_button_props
scope.9.kind=function
scope.9.startLine=73
scope.9.endLine=79
scope.9.semanticHash=24589e45f91fec24
scope.10.id=function:_has_price
scope.10.kind=function
scope.10.startLine=81
scope.10.endLine=83
scope.10.semanticHash=6321215b00a3799c
scope.11.id=function:_is_owned_status
scope.11.kind=function
scope.11.startLine=85
scope.11.endLine=87
scope.11.semanticHash=4660cf802f43a770
scope.12.id=function:_price_icon_visible
scope.12.kind=function
scope.12.startLine=89
scope.12.endLine=91
scope.12.semanticHash=e7c038bdf446ce31
scope.13.id=function:_skin_field
scope.13.kind=function
scope.13.startLine=93
scope.13.endLine=95
scope.13.semanticHash=cd6b189045fad21d
scope.14.id=function:_skin_fields
scope.14.kind=function
scope.14.startLine=97
scope.14.endLine=104
scope.14.semanticHash=7fc8a553225d8235
scope.15.id=function:read_model.slot_view_model
scope.15.kind=function
scope.15.startLine=106
scope.15.endLine=124
scope.15.semanticHash=e4b67d8a2190969a
scope.16.id=function:read_model.slot_view_models
scope.16.kind=function
scope.16.startLine=126
scope.16.endLine=132
scope.16.semanticHash=cae74b60cdbd85c0
scope.17.id=function:read_model.clamp_page
scope.17.kind=function
scope.17.startLine=134
scope.17.endLine=136
scope.17.semanticHash=e099514727f70886
]]
