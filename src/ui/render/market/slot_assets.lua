local market_layout = require("src.ui.schema.market_layout")
local runtime_assets = require("src.config.runtime_assets")
local number_utils = require("src.foundation.number")

local slot_assets = {}

local function _asset_opts(refs)
  if type(refs) ~= "table" then
    return nil
  end
  if type(refs.refs) == "table" or type(refs.images) == "table" then
    return refs
  end
  return { refs = { images = refs } }
end

local function _icon_key(refs, product_id, entry, cfg)
  local name = (cfg and cfg.name) or (entry and entry.name)
  local image = runtime_assets.image_for_market_item(product_id, name, _asset_opts(refs))
  return image.ok == true and image.image_key or nil
end

function slot_assets.price_text(entry)
  local currency = assert(
    entry.currency ~= nil and entry.currency ~= "" and entry.currency,
    "missing market currency"
  )
  return number_utils.format_integer_part(entry.price) .. " " .. tostring(currency)
end

local function _fallback_icon_key(refs, empty_ref_key)
  local rarity = runtime_assets.image_for_market_rarity(empty_ref_key, _asset_opts(refs))
  if rarity.image_key ~= nil then
    return rarity.image_key
  end
  return runtime_assets.empty_image(_asset_opts(refs)).image_key
end

function slot_assets.selection_icon_key(refs, option_id, entry, cfg, empty_ref_key)
  return _icon_key(refs, option_id, entry, cfg)
    or _fallback_icon_key(refs, empty_ref_key)
end

function slot_assets.rarity_key(refs, level)
  local image = runtime_assets.image_for_market_rarity(market_layout.rarity_ref_keys[level], _asset_opts(refs))
  if image.ok == true then
    return image.image_key
  end
  local empty = runtime_assets.empty_image(_asset_opts(refs))
  return empty.image_key
end

return slot_assets

--[[ mutate4lua-manifest
version=2
projectHash=b0bfca276c14d537
scope.0.id=chunk:src/ui/render/market/slot_assets.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=53
scope.0.semanticHash=b0dda2e92a465579
scope.1.id=function:_asset_opts:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=14
scope.1.semanticHash=ad0ee3585a4ae9a7
scope.2.id=function:_icon_key:16
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=20
scope.2.semanticHash=20f24ed5000b87bf
scope.3.id=function:slot_assets.price_text:22
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=28
scope.3.semanticHash=7734c4e7ab5c7767
scope.4.id=function:_fallback_icon_key:30
scope.4.kind=function
scope.4.startLine=30
scope.4.endLine=36
scope.4.semanticHash=7e6433190a1d191c
scope.5.id=function:slot_assets.selection_icon_key:38
scope.5.kind=function
scope.5.startLine=38
scope.5.endLine=41
scope.5.semanticHash=35843c9f79df2321
scope.6.id=function:slot_assets.rarity_key:43
scope.6.kind=function
scope.6.startLine=43
scope.6.endLine=50
scope.6.semanticHash=af94b52006c57a26
]]
