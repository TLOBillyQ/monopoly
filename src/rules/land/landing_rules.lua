local board_utils = require("src.rules.land.board_utils")
local achievement_hooks = require("src.rules.land.achievement_hooks")
local item_ids = require("src.config.gameplay.item_ids")
local inventory = require("src.rules.items.inventory")
local use_broadcast = require("src.rules.items.use_broadcast")
local rent_resolver = require("src.rules.land.rent_resolver")
local rent_payment = require("src.rules.land.rent_payment")
local tax_rules = require("src.rules.land.tax_rules")
local achievement_progress = require("src.rules.ports.achievement_progress")
local number_utils = require("src.foundation.number")

local land_rules = {}
land_rules.safe_tile_state = rent_resolver.safe_tile_state
land_rules.resolve_rent_owner = rent_resolver.resolve_rent_owner
land_rules.contiguous_rent = rent_resolver.contiguous_rent
land_rules.contiguous_count = rent_resolver.contiguous_count
land_rules.contiguous_breakdown = rent_resolver.contiguous_breakdown

local function _resolve_player_and_tile(game, player_id, tile_id)
  local player = game:find_player_by_id(player_id)
  local tile = game.board:get_tile_by_id(tile_id)
  return player, tile
end

local function _resolve_owner(game, owner_id)
  if not owner_id then
    return nil
  end
  return game:find_player_by_id(owner_id)
end

local function _build_land_event(event_key, payload, extra)
  local result = {
    ok = true,
    event = event_key,
    payload = payload,
  }
  if extra then
    for key, value in pairs(extra) do
      result[key] = value
    end
  end
  return result
end

function land_rules.execute_strong_card(game, player_id, tile_id)
  local player, tile = _resolve_player_and_tile(game, player_id, tile_id)
  local st = land_rules.safe_tile_state(game, tile)
  local owner = _resolve_owner(game, st.owner_id)
  assert(owner ~= nil, "missing owner")

  local total_value = board_utils.total_invested(tile, st.level)
  if game:player_balance(player, "金币") < total_value then
    return { ok = false, reason = "insufficient_balance" }
  end
  assert(inventory.consume(player, item_ids.strong) == true, "consume strong card failed")
  use_broadcast.dispatch(game, player, item_ids.strong)
  game:transfer_player_cash(player, owner, total_value)
  game:set_tile_owner(tile, player.id)
  game:set_player_property(owner, tile.id, false)
  game:set_player_property(player, tile.id, true)
  achievement_progress.item_used(game, player)
  achievement_progress.cash_received(game, owner, total_value)
  achievement_progress.land_purchased(game, player)
  achievement_hooks.record_contiguous_if_reached(game, player, tile)
  return _build_land_event("strong_card_used", {
    player = player,
    owner = owner,
    tile = tile,
    amount = total_value,
    text = player.name .. " 使用强征卡，支付 " .. number_utils.format_integer_part(total_value) .. " 强制购入 " .. tile.name,
  })
end

function land_rules.execute_free_card(game, player_id, tile_id)
  local player, tile = _resolve_player_and_tile(game, player_id, tile_id)
  assert(inventory.consume(player, item_ids.free_rent) == true, "consume free rent failed")
  achievement_progress.item_used(game, player)
  use_broadcast.dispatch(game, player, item_ids.free_rent)
  return _build_land_event("free_rent_used", {
    player = player,
    tile = tile,
    text = player.name .. " 出示免费卡，免租 " .. tile.name,
  })
end

land_rules.execute_pay_rent = rent_payment.execute_pay_rent
land_rules.execute_tax_free_card = tax_rules.execute_tax_free_card
land_rules.execute_pay_tax = tax_rules.execute_pay_tax

return land_rules

--[[ mutate4lua-manifest
version=2
projectHash=7a79e6d5299647b5
scope.0.id=chunk:src/rules/land/landing_rules.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=92
scope.0.semanticHash=56a24756322eec40
scope.1.id=function:_resolve_player_and_tile:19
scope.1.kind=function
scope.1.startLine=19
scope.1.endLine=23
scope.1.semanticHash=c7fed37020d8b505
scope.2.id=function:_resolve_owner:25
scope.2.kind=function
scope.2.startLine=25
scope.2.endLine=30
scope.2.semanticHash=e888b93920a60814
scope.3.id=function:land_rules.execute_strong_card:46
scope.3.kind=function
scope.3.startLine=46
scope.3.endLine=73
scope.3.semanticHash=241c3ff2a0fb7c6b
scope.4.id=function:land_rules.execute_free_card:75
scope.4.kind=function
scope.4.startLine=75
scope.4.endLine=85
scope.4.semanticHash=14b8de52362c0e88
]]
