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

local function _item_display_name(cfg, entry)
  return (cfg and cfg.name) or (entry and entry.name)
end

local function _icon_key(refs, product_id, entry, cfg)
  local image = runtime_assets.image_for_market_item(product_id, _item_display_name(cfg, entry), _asset_opts(refs))
  return image.ok == true and image.image_key or nil
end

function slot_assets.price_text(entry)
  local currency = assert(
    entry.currency ~= nil and entry.currency ~= "" and entry.currency,
    "missing market currency"
  )
  return number_utils.format_integer_part(entry.price) .. " " .. tostring(currency)
end

local function _empty_icon_key(refs)
  return runtime_assets.empty_image(_asset_opts(refs)).image_key
end

function slot_assets.selection_icon_key(refs, option_id, entry, cfg)
  return _icon_key(refs, option_id, entry, cfg)
    or _empty_icon_key(refs)
end

return slot_assets

--[[ mutate4lua-manifest
version=4
projectHash=484164a6d3d7922d
scope.0.id=chunk:src/ui/render/market/slot_assets.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=43
scope.0.semanticHash=e2d7f2de67b8096c
scope.1.id=function:_asset_opts
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=14
scope.1.semanticHash=2167c8544f07ab03
scope.2.id=function:_item_display_name
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=18
scope.2.semanticHash=0a83334b554c259f
scope.3.id=function:_icon_key
scope.3.kind=function
scope.3.startLine=20
scope.3.endLine=23
scope.3.semanticHash=1472c6eede1f3cd6
scope.4.id=function:slot_assets.price_text
scope.4.kind=function
scope.4.startLine=25
scope.4.endLine=31
scope.4.semanticHash=4889307ec240f0b2
scope.5.id=function:_empty_icon_key
scope.5.kind=function
scope.5.startLine=33
scope.5.endLine=35
scope.5.semanticHash=d24d449cd044b7b0
scope.6.id=function:slot_assets.selection_icon_key
scope.6.kind=function
scope.6.startLine=37
scope.6.endLine=40
scope.6.semanticHash=5ce3621153f5450c
]]
