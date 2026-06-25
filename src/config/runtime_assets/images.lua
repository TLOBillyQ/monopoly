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

function M.image_for_market_rarity(ref_key, opts)
  return results.image_result("market.rarity_frame", ref_key, "missing_market_rarity_frame", opts)
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
version=2
projectHash=c9c64873cab65bcb
scope.0.id=chunk:src/config/runtime_assets/images.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=77
scope.0.semanticHash=d24ecdba22c3e272
scope.1.id=function:M.image_for_item:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=9
scope.1.semanticHash=e7e3d6bc97e2487b
scope.2.id=function:M.image_for_chance_card:11
scope.2.kind=function
scope.2.startLine=11
scope.2.endLine=13
scope.2.semanticHash=d6095d66ea1460b6
scope.3.id=function:M.image_for_skin_card:15
scope.3.kind=function
scope.3.startLine=15
scope.3.endLine=17
scope.3.semanticHash=1edee267e3963e8c
scope.4.id=function:M.empty_image:19
scope.4.kind=function
scope.4.startLine=19
scope.4.endLine=21
scope.4.semanticHash=126babd76ef59df8
scope.5.id=function:M.image_for_popup_card:23
scope.5.kind=function
scope.5.startLine=23
scope.5.endLine=26
scope.5.semanticHash=61c06270729a6bd2
scope.6.id=function:M.image_for_market_item:28
scope.6.kind=function
scope.6.startLine=28
scope.6.endLine=37
scope.6.semanticHash=c37a1406b3c70ff7
scope.7.id=function:M.image_for_market_rarity:39
scope.7.kind=function
scope.7.startLine=39
scope.7.endLine=41
scope.7.semanticHash=e41dcca7a32c3026
scope.8.id=function:M.startup_item_slot_icon:43
scope.8.kind=function
scope.8.startLine=43
scope.8.endLine=47
scope.8.semanticHash=246fa3feefd82d33
scope.9.id=function:M.skin_model_for_product:49
scope.9.kind=function
scope.9.startLine=49
scope.9.endLine=63
scope.9.semanticHash=415bb6767f1e6471
scope.10.id=function:M.default_skin_model:65
scope.10.kind=function
scope.10.startLine=65
scope.10.endLine=74
scope.10.semanticHash=98c5fc8ea80ded46
]]
