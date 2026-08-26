local number_utils = require("src.foundation.number")
local state = require("src.config.runtime_assets.state")
local results = require("src.config.runtime_assets.results")

local M = {}

function M.image_for_item(item_id, opts)
  return results.image_result("item.icon", item_id, "missing_item_icon", opts)
end

function M.image_for_chance_card(card_id, opts)
  return results.image_result("chance.icon", card_id, "missing_chance_card_icon", opts)
end

function M.image_for_skin_card(product_id, opts)
  return results.image_result("skin.card_image", product_id, "missing_skin_card_image", opts)
end

function M.empty_image(opts)
  return results.image_result("empty.image", "Empty", "missing_empty_image", opts)
end

function M.image_for_popup_card(kind, image_ref, opts)
  local meaning = kind == "item_card" and "popup.item_card_image" or "popup.chance_card_image"
  return results.image_result(meaning, image_ref, "missing_popup_card_image", opts)
end

function M.image_for_market_item(product_id, display_name, opts)
  local primary = results.image_result("market.item_icon", product_id, "missing_market_item_icon", opts)
  if primary.ok == true or display_name == nil or display_name == "" then
    return primary
  end
  local fallback = results.image_result("market.item_icon", display_name, "missing_market_item_icon", opts)
  fallback.primary_lookup_key = primary.lookup_key
  fallback.fallback_used = fallback.ok == true
  return fallback
end

function M.startup_item_slot_icon(slot_index, opts)
  local slot = number_utils.to_integer(slot_index)
  local raw_key = slot and state.startup_item_ids()[slot] or nil
  return results.image_result("ui.startup_item_slot_icon", raw_key, "missing_startup_item_icon", opts)
end

function M.skin_model_for_product(product_id, opts)
  local refs = state.refs(opts)
  local lookup_key = results.key(product_id)
  local asset_id = product_id ~= nil and (refs.skins or {})[lookup_key] or nil
  if asset_id == nil then
    return results.missing("skin.model", "missing_skin_model", {
      lookup_key = lookup_key,
    })
  end
  return results.result("skin.model", {
    asset_id = asset_id,
    lookup_key = lookup_key,
    fallback_used = false,
  })
end

function M.default_skin_model(opts)
  local asset_id = state.refs(opts).default_creature
  if asset_id == nil then
    return results.missing("skin.default_model", "missing_default_skin_model")
  end
  return results.result("skin.default_model", {
    asset_id = asset_id,
    fallback_used = false,
  })
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=2c164b448aab78c3
scope.0.id=chunk:src/config/runtime_assets/images.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=73
scope.0.semanticHash=b238b15ff19bc4fb
scope.1.id=function:M.image_for_item
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=9
scope.1.semanticHash=9cbb2bd797bad8d5
scope.2.id=function:M.image_for_chance_card
scope.2.kind=function
scope.2.startLine=11
scope.2.endLine=13
scope.2.semanticHash=9cbb2bd797bad8d5
scope.3.id=function:M.image_for_skin_card
scope.3.kind=function
scope.3.startLine=15
scope.3.endLine=17
scope.3.semanticHash=9cbb2bd797bad8d5
scope.4.id=function:M.empty_image
scope.4.kind=function
scope.4.startLine=19
scope.4.endLine=21
scope.4.semanticHash=99a2131041a3e17d
scope.5.id=function:M.image_for_popup_card
scope.5.kind=function
scope.5.startLine=23
scope.5.endLine=26
scope.5.semanticHash=ad0b3f91796fec0a
scope.6.id=function:M.image_for_market_item
scope.6.kind=function
scope.6.startLine=28
scope.6.endLine=37
scope.6.semanticHash=eea7f7030543ec2a
scope.7.id=function:M.startup_item_slot_icon
scope.7.kind=function
scope.7.startLine=39
scope.7.endLine=43
scope.7.semanticHash=181ae626e56a50b1
scope.8.id=function:M.skin_model_for_product
scope.8.kind=function
scope.8.startLine=45
scope.8.endLine=59
scope.8.semanticHash=4925460728db048f
scope.9.id=function:M.default_skin_model
scope.9.kind=function
scope.9.startLine=61
scope.9.endLine=70
scope.9.semanticHash=889b94b0a817972e
]]
