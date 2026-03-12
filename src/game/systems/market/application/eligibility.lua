local inventory = require("src.game.systems.items.inventory")
local context = require("src.game.systems.market.application.context")
local paid_purchase_port = require("src.game.systems.market.ports.paid_purchase_port")

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
    local ok = paid_purchase_port.can_start(game, player, entry)
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

local function _split_entries_by_buyable(player, game)
  local buyable = {}
  local unbuyable = {}
  for _, entry in ipairs(eligibility.sorted_entries()) do
    if eligibility.can_buy_entry(game, player, entry) then
      buyable[#buyable + 1] = entry
    else
      unbuyable[#unbuyable + 1] = entry
    end
  end
  return buyable, unbuyable
end

local function _append_visible_entries(visible, entries, can_buy, limit)
  for _, entry in ipairs(entries) do
    visible[#visible + 1] = { entry = entry, can_buy = can_buy }
    if limit and #visible >= limit then
      return true
    end
  end
  return false
end

function eligibility.build_visible_entries(player, game, limit)
  local buyable, unbuyable = _split_entries_by_buyable(player, game)
  local visible = {}
  if _append_visible_entries(visible, buyable, true, limit) then
    return visible, buyable
  end
  _append_visible_entries(visible, unbuyable, false, limit)
  return visible, buyable
end

return eligibility
