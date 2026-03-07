local inventory = require("src.game.systems.items.item_inventory")
local context = require("src.game.systems.market.application.context")
local purchase = require("src.game.systems.market.application.purchase")

local eligibility = {}

function eligibility.can_buy_entry(game, player, entry)
  if not context.entry_vehicle_enabled(entry) then
    return false
  end
  if not context.entry_market_enabled(entry) then
    return false
  end
  if entry.kind == "item" and inventory.is_full(player) then
    return false
  end
  local remaining = context.remaining_global_limit(game, entry.product_id)
  if remaining <= 0 then
    return false
  end
  local price = context.entry_price(entry)
  local currency = context.entry_currency(entry)
  if context.is_paid_currency(currency) then
    local ok = purchase.can_start_external_purchase(game, player, entry)
    return ok == true
  end
  context.sync_managed_balance(game, player, currency)
  return game:player_balance(player, currency) >= price
end

function eligibility.sorted_entries()
  local entries = {}
  for _, entry in ipairs(context.entries()) do
    entries[#entries + 1] = entry
  end
  table.sort(entries, function(a, b)
    return (a.order or 0) < (b.order or 0)
  end)
  return entries
end

function eligibility.list_available(player, game)
  local list = {}
  for _, entry in ipairs(context.entries()) do
    if eligibility.can_buy_entry(game, player, entry) then
      list[#list + 1] = entry
    end
  end
  table.sort(list, function(a, b)
    return (a.order or 0) < (b.order or 0)
  end)
  return list
end

function eligibility.build_visible_entries(player, game, limit)
  local buyable = {}
  local unbuyable = {}
  for _, entry in ipairs(eligibility.sorted_entries()) do
    if eligibility.can_buy_entry(game, player, entry) then
      buyable[#buyable + 1] = entry
    else
      unbuyable[#unbuyable + 1] = entry
    end
  end

  local visible = {}
  for _, entry in ipairs(buyable) do
    visible[#visible + 1] = { entry = entry, can_buy = true }
    if limit and #visible >= limit then
      return visible, buyable
    end
  end
  for _, entry in ipairs(unbuyable) do
    visible[#visible + 1] = { entry = entry, can_buy = false }
    if limit and #visible >= limit then
      return visible, buyable
    end
  end
  return visible, buyable
end

return eligibility
