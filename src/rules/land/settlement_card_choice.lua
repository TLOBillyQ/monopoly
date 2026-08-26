local inventory = require("src.rules.items.inventory")
local item_ids = require("src.config.gameplay.item_ids")
local land_actions = require("src.rules.land.actions")
local shared = require("src.rules.land.settlement_shared")

local card_choice = {}

local function _rent_card_executor(execute)
  return function(game, player_id, tile_id)
    execute(game, player_id, tile_id)
    return true
  end
end

local function _ignore_selected_rent_card()
  return false
end

local rent_card_executors = {
  strong = _rent_card_executor(land_actions.execute_strong_card),
  free = _rent_card_executor(land_actions.execute_free_card),
}

local function _execute_selected_rent_card(game, player_id, tile_id, card_kind)
  local executor = rent_card_executors[card_kind] or _ignore_selected_rent_card
  return executor(game, player_id, tile_id)
end

local function _try_auto_free_rent(game, player_id, tile_id, card_kind)
  if card_kind ~= "strong" then
    return nil
  end
  local player = shared.resolve_actor(game, player_id)
  if player == nil then
    return shared.reject("missing_actor")
  end
  if inventory.find_index(player, item_ids.free_rent) then
    land_actions.execute_free_card(game, player_id, tile_id)
    return { ok = true, status = "resolved", effect_id = "free_rent" }
  end
  return nil
end

local function _pay_rent(game, player_id, tile_id)
  land_actions.execute_pay_rent(game, player_id, tile_id)
  return { ok = true, status = "resolved", effect_id = "pay_rent" }
end

function card_choice.resolve_rent(game, choice, action)
  local meta, meta_error = shared.choice_meta(choice)
  if meta_error then return meta_error end

  local player_id = meta.player_id
  local tile_id = meta.tile_id
  local card_kind = meta.card_kind
  local use_card = shared.option_id_from_action(action) == "use"

  if use_card and _execute_selected_rent_card(game, player_id, tile_id, card_kind) then
    return { ok = true, status = "resolved", effect_id = "pay_rent" }
  end

  local fallback = _try_auto_free_rent(game, player_id, tile_id, card_kind)
  if fallback then return fallback end

  return _pay_rent(game, player_id, tile_id)
end

function card_choice.resolve_tax(game, choice, action)
  local meta, meta_error = shared.choice_meta(choice)
  if meta_error then return meta_error end

  local player_id = meta.player_id
  local use_card = shared.option_id_from_action(action) == "use"

  if use_card then
    land_actions.execute_tax_free_card(game, player_id)
    return { ok = true, status = "resolved", effect_id = "tax_free" }
  end

  land_actions.execute_pay_tax(game, player_id)
  return { ok = true, status = "resolved", effect_id = "pay_tax" }
end

return card_choice

--[[ mutate4lua-manifest
version=4
projectHash=993c3e6a5f9eb24b
scope.0.id=chunk:src/rules/land/settlement_card_choice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=85
scope.0.semanticHash=214b7f857b11fc63
scope.1.id=function:_rent_card_executor
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=13
scope.1.semanticHash=9c10066f52e16059
scope.2.id=function:<anonymous>
scope.2.kind=function
scope.2.startLine=9
scope.2.endLine=12
scope.2.semanticHash=363575cc05fd060c
scope.3.id=function:_ignore_selected_rent_card
scope.3.kind=function
scope.3.startLine=15
scope.3.endLine=17
scope.3.semanticHash=22b57f529f3a8828
scope.4.id=function:_execute_selected_rent_card
scope.4.kind=function
scope.4.startLine=24
scope.4.endLine=27
scope.4.semanticHash=25622b4a5a1a87d5
scope.5.id=function:_try_auto_free_rent
scope.5.kind=function
scope.5.startLine=29
scope.5.endLine=42
scope.5.semanticHash=3f0d1c20db9f5b68
scope.6.id=function:_pay_rent
scope.6.kind=function
scope.6.startLine=44
scope.6.endLine=47
scope.6.semanticHash=1baf6dd738745c4c
scope.7.id=function:card_choice.resolve_rent
scope.7.kind=function
scope.7.startLine=49
scope.7.endLine=66
scope.7.semanticHash=7d52d1def9b1ae97
scope.8.id=function:card_choice.resolve_tax
scope.8.kind=function
scope.8.startLine=68
scope.8.endLine=82
scope.8.semanticHash=e739c19a6f47147e
]]
