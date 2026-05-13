local board_utils = require("src.rules.land.board_utils")
local constants = require("src.config.content.constants")
local item_ids = require("src.config.gameplay.item_ids")
local inventory = require("src.rules.items.inventory")
local use_broadcast = require("src.rules.items.use_broadcast")
local rent_resolver = require("src.rules.land.rent_resolver")
local number_utils = require("src.foundation.lang.number")

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
  game:deduct_player_cash(player, total_value)
  game:add_player_cash(owner, total_value)
  game:set_tile_owner(tile, player.id)
  game:set_player_property(owner, tile.id, false)
  game:set_player_property(player, tile.id, true)
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
  use_broadcast.dispatch(game, player, item_ids.free_rent)
  return _build_land_event("free_rent_used", {
    player = player,
    tile = tile,
    text = player.name .. " 出示免费卡，免租 " .. tile.name,
  })
end

function land_rules.execute_pay_rent(game, player_id, tile_id)
  local player, tile = _resolve_player_and_tile(game, player_id, tile_id)
  local owner, _, skip = land_rules.resolve_rent_owner(game, tile)
  if skip and skip.reason == "mountain" then
    return {
      ok = false,
      event = "rent_skipped_mountain",
      payload = {
        owner = skip.owner,
        tile = tile,
        text = skip.owner.name .. " 在深山，租金不收取",
      },
    }
  end
  if not owner then
    return { ok = false, reason = "no_owner" }
  end

  local board = game.board
  local idx = assert(board:index_of_tile_id(tile.id), "missing tile index: " .. tostring(tile.id))
  local breakdown = land_rules.contiguous_breakdown(game, board, idx, owner.id)
  local rent = breakdown.total_rent

  local poor_active = game:player_has_deity(player, "poor")
  local rich_active = game:player_has_deity(owner, "rich")
  local deity_multiplier = 1
  if poor_active then
    rent = rent * 2
    deity_multiplier = deity_multiplier * 2
  end
  if rich_active then
    rent = rent * 2
    deity_multiplier = deity_multiplier * 2
  end

  local text = player.name .. " 向 " .. owner.name .. " 支付租金 " .. number_utils.format_integer_part(rent)

  local breakdown_parts = {}
  if breakdown.count > 1 then
    local rent_strs = {}
    for _, r in ipairs(breakdown.rents) do
      rent_strs[#rent_strs + 1] = number_utils.format_integer_part(r)
    end
    breakdown_parts[#breakdown_parts + 1] = "连片 " .. table.concat(rent_strs, " + ")
  end
  if deity_multiplier > 1 then
    local deity_label = nil
    if poor_active and rich_active then
      deity_label = "穷神/财神"
    elseif poor_active then
      deity_label = "穷神"
    elseif rich_active then
      deity_label = "财神"
    end
    if deity_label then
      breakdown_parts[#breakdown_parts + 1] = deity_label .. " ×" .. tostring(deity_multiplier)
    end
  end

  local multiplier_text = nil
  if #breakdown_parts > 0 then
    if deity_multiplier > 1 then
      multiplier_text = tile.name .. " 租金 ×" .. tostring(deity_multiplier) .. "（" .. table.concat(breakdown_parts, "，") .. "）"
    else
      multiplier_text = tile.name .. " 租金（" .. table.concat(breakdown_parts, "，") .. "）"
    end
  end

  local result = _build_land_event("rent_paid", {
    player = player,
    owner = owner,
    tile = tile,
    amount = rent,
    single_rent = breakdown.single_rent,
    contiguous_count = breakdown.count,
    deity_multiplier = deity_multiplier,
    text = text,
    multiplier_text = multiplier_text,
  })

  if game:player_balance(player, "金币") >= rent then
    game:deduct_player_cash(player, rent)
    game:add_player_cash(owner, rent)
    return result
  end

  local liquid = game:player_balance(player, "金币")
  game:add_player_cash(player, -rent)
  game:add_player_cash(owner, liquid)
  local reason = player.name .. " 资金不足，欠付(" .. owner.name .. ") " .. number_utils.format_integer_part(rent) .. " 破产"
  result.event = "rent_bankrupt"
  result.payload.amount = rent
  result.payload.text = reason
  result.bankrupt_reason = reason
  return result
end

function land_rules.execute_tax_free_card(game, player_id)
  local player = game:find_player_by_id(player_id)
  assert(inventory.consume(player, item_ids.tax_free) == true, "consume tax_free failed")
  use_broadcast.dispatch(game, player, item_ids.tax_free)
  return _build_land_event("tax_free", {
    player = player,
    text = player.name .. " 出示免税卡，本次免税",
  })
end

function land_rules.execute_pay_tax(game, player_id)
  local player = game:find_player_by_id(player_id)
  local cash = game:player_balance(player, "金币")
  local fee = math.floor(cash * constants.tax_rate)
  if cash < fee then fee = cash end

  game:deduct_player_cash(player, fee)
  local result = _build_land_event("tax_paid", {
    player = player,
    amount = fee,
    text = player.name .. " 在税务局支付税金 " .. number_utils.format_integer_part(fee),
  })
  if game:player_balance(player, "金币") <= 0 then
    result.bankrupt_reason = player.name .. " 支付税金后破产"
  end
  return result
end

return land_rules
