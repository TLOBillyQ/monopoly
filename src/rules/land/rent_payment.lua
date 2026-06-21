local rent_resolver = require("src.rules.land.rent_resolver")
local achievement_progress = require("src.rules.ports.achievement_progress")
local number_utils = require("src.foundation.number")

local rent_payment = {}

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

local function _compute_deity_rent(poor_active, rich_active, initial_rent)
  local rent = initial_rent
  local multiplier = 1
  if poor_active then
    rent = rent * 2
    multiplier = multiplier * 2
  end
  if rich_active then
    rent = rent * 2
    multiplier = multiplier * 2
  end
  return rent, multiplier
end

local deity_labels = {
  ["true:false"] = "穷神",
  ["false:true"] = "财神",
  ["true:true"] = "穷神/财神",
}

local function _build_deity_label(poor_active, rich_active)
  return deity_labels[tostring(poor_active == true) .. ":" .. tostring(rich_active == true)]
end

local function _build_breakdown_parts(breakdown, poor_active, rich_active, deity_multiplier)
  local parts = {}
  if breakdown.count > 1 then
    local rent_strs = {}
    for _, r in ipairs(breakdown.rents) do
      rent_strs[#rent_strs + 1] = number_utils.format_integer_part(r)
    end
    parts[#parts + 1] = "连片 " .. table.concat(rent_strs, " + ")
  end
  if deity_multiplier > 1 then
    local label = _build_deity_label(poor_active, rich_active)
    if label then
      parts[#parts + 1] = label .. " ×" .. tostring(deity_multiplier)
    end
  end
  return parts
end

local function _build_multiplier_text(breakdown_parts, deity_multiplier, tile_name)
  if #breakdown_parts == 0 then return nil end
  local joined = table.concat(breakdown_parts, "，")
  if deity_multiplier > 1 then
    return tile_name .. " 租金 ×" .. tostring(deity_multiplier) .. "（" .. joined .. "）"
  end
  return tile_name .. " 租金（" .. joined .. "）"
end

function rent_payment.execute_pay_rent(game, player_id, tile_id)
  local player = game:find_player_by_id(player_id)
  local tile = game.board:get_tile_by_id(tile_id)
  local owner, _, skip = rent_resolver.resolve_rent_owner(game, tile)
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
  local breakdown = rent_resolver.contiguous_breakdown(game, board, idx, owner.id)
  local poor_active = game:player_has_deity(player, "poor")
  local rich_active = game:player_has_deity(owner, "rich")
  local rent, deity_multiplier = _compute_deity_rent(poor_active, rich_active, breakdown.total_rent)
  local breakdown_parts = _build_breakdown_parts(breakdown, poor_active, rich_active, deity_multiplier)
  local multiplier_text = _build_multiplier_text(breakdown_parts, deity_multiplier, tile.name)
  local text = player.name .. " 向 " .. owner.name .. " 支付租金 " .. number_utils.format_integer_part(rent)

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
    achievement_progress.cash_received(game, owner, rent)
    return result
  end

  local liquid = game:player_balance(player, "金币")
  game:add_player_cash(player, -rent)
  game:add_player_cash(owner, liquid)
  achievement_progress.cash_received(game, owner, liquid)
  local reason = player.name .. " 资金不足，欠付(" .. owner.name .. ") " .. number_utils.format_integer_part(rent) .. " 破产"
  result.event = "rent_bankrupt"
  result.payload.amount = rent
  result.payload.text = reason
  result.bankrupt_reason = reason
  return result
end

return rent_payment
