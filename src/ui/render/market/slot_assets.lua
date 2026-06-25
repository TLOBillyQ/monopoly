local market_layout = require("src.ui.schema.market_layout")
local runtime_assets = require("src.config.runtime_assets")

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
  return tostring(entry.price) .. " " .. tostring(currency)
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
